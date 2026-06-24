import SwiftHTML
import Synchronization

/// Collects the atomic CSS rules used during one render pass and hands back a
/// deterministic, deduplicated class for each declaration, so styling is expressed
/// as classes instead of inline `style="…"`. See `docs/AtomicStyling.md`.
final class StyleRegistry: Sendable {
    // class name -> declaration body ("property: value")
    private let store: Mutex<[String: String]>

    init() {
        store = Mutex([:])
    }

    /// The render-scoped registry. Bound per server render and per client reconcile,
    /// mirroring `Transaction.current`; `atom(_:)` writes to whatever is current.
    @TaskLocal static var current: StyleRegistry?

    /// Register a `Style`'s declarations as atomic classes and return the space-joined
    /// class names. Each declaration is validated first: a value that could escape its
    /// rule inside a `<style>` block fails loudly in debug and is dropped in release —
    /// never injected verbatim.
    func register(_ style: Style) -> String {
        var names: [String] = []
        for declaration in Self.declarations(of: style) {
            guard Self.isSafe(property: declaration.property, value: declaration.value) else {
                assertionFailure("Rejected unsafe CSS declaration: \(declaration.property): \(declaration.value)")
                continue
            }
            let name = Self.className(property: declaration.property, value: declaration.value)
            store.withLock { $0[name] = "\(declaration.property): \(declaration.value)" }
            names.append(name)
        }
        return names.joined(separator: " ")
    }

    /// Every collected rule, sorted for stable output, for emission into a `<style>` block.
    func rules() -> [(className: String, body: String)] {
        store.withLock { storage in
            storage.keys.sorted().map { ($0, storage[$0]!) }
        }
    }

    // MARK: - Declaration parsing
    // `Style.declarations` is internal to SwiftHTML, so parse the public `cssText`
    // ("prop: value; prop: value"). Values use commas, not "; ", so the split is safe.

    private static func declarations(of style: Style) -> [(property: String, value: String)] {
        style.cssText
            .components(separatedBy: "; ")
            .compactMap { segment in
                guard let separator = segment.range(of: ": ") else { return nil }
                let property = String(segment[..<separator.lowerBound])
                let value = String(segment[separator.upperBound...])
                guard !property.isEmpty, !value.isEmpty else { return nil }
                return (property, value)
            }
    }

    // MARK: - Validation
    // Reject anything that could close a rule or inject a new selector once the value
    // moves from an inline attribute into a `<style>` block.

    static func isSafe(property: String, value: String) -> Bool {
        guard let first = property.first else { return false }
        let propertyOK = (first.isLetter || property.hasPrefix("-"))
            && property.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        let unsafe: Set<Character> = ["{", "}", "<", ">", ";", "@", "\\"]
        let hasControl = value.unicodeScalars.contains { $0.value < 0x20 }
        let valueOK = !value.contains(where: { unsafe.contains($0) })
            && !hasControl
            && !value.contains("/*")
            && !value.contains("*/")
        return propertyOK && valueOK
    }

    // MARK: - Class name
    // Pure function of the canonical (property, value-with-unit) so the server and the
    // WASM client compute the same class for the same declaration -> automatic dedup.

    static func className(property: String, value: String) -> String {
        let prefix = abbreviation(for: property)
        let encoded = encode(value)
        if !encoded.isEmpty, encoded.count <= 16 {
            return "swui-\(prefix)-\(encoded)"
        }
        return "swui-\(prefix)-x\(fnv1a(property + ":" + value))"
    }

    private static let abbreviations: [String: String] = [
        "width": "w", "height": "h", "min-width": "minw", "max-width": "maxw",
        "min-height": "minh", "max-height": "maxh", "padding": "p", "margin": "m",
        "border-radius": "r", "opacity": "o", "color": "c", "background": "bg",
        "background-color": "bg", "box-shadow": "shadow", "flex-grow": "grow",
        "justify-content": "jc", "align-items": "ai", "text-align": "ta",
    ]

    private static func abbreviation(for property: String) -> String {
        if let abbreviation = abbreviations[property] { return abbreviation }
        return property.map { $0.isLetter || $0.isNumber ? String($0) : "" }.joined()
    }

    /// Canonicalize a value into an identifier-safe token, preserving unit so `13px`
    /// and `13em` differ. Returns "" when the value is not simple (use the hash path).
    private static func encode(_ value: String) -> String {
        var out = ""
        for character in value {
            switch character {
            case "a"..."z", "A"..."Z", "0"..."9": out.append(character)
            case ".": out.append("_")
            case "%": out.append("pct")
            case "-": out.append("n")
            default: return ""
            }
        }
        return out
    }

    private static func fnv1a(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

/// Register `style` as atomic classes through the current `StyleRegistry` and return a
/// `class` attribute. With no registry in scope (e.g. a component rendered in isolation,
/// outside a page), it falls back to an inline `style` — that is the no-collector path,
/// not error masking.
func atom(_ style: Style) -> HTMLAttribute {
    guard !style.isEmpty else { return .class("") }
    if let registry = StyleRegistry.current {
        return .class(registry.register(style))
    }
    return styleAttribute(style)
}
