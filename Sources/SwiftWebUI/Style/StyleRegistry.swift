import SwiftHTML
import Synchronization

/// Collects the atomic CSS rules used during one render pass and hands back a
/// deterministic, deduplicated class for each declaration, so styling is expressed
/// as classes instead of inline `style="…"`. See `docs/AtomicStyling.md`.
///
/// Lives in its own low module so the three consumers — SwiftWebUI (`atom` + the
/// modifier layer), SwiftWeb/SwiftWebCore (server collect + emit), and
/// SwiftWebClientRuntime (client flush) — can all reach it without depending on the
/// component library.
public final class StyleRegistry: Sendable {
    // Insertion-ordered, deduplicated collection so the emitted `<style>` preserves
    // declaration order — shorthand/longhand and fallback cascades depend on it.
    private struct Collected {
        var order: [String] = []
        var bodies: [String: String] = [:]
        var stylesheetOrder: [String] = []
        var stylesheets: Set<String> = []
        var scriptOrder: [String] = []
        var scripts: [String: String] = [:]
    }
    private let collected: Mutex<Collected>

    public init() {
        collected = Mutex(Collected())
    }

    /// The render-scoped registry that `atom(_:)` writes to. It is task-local for normal
    /// render/reconcile isolation; `withCurrent(_:_:)` also installs an enlarged-stack
    /// propagator so SwiftHTML's dedicated render thread sees the same binding.
    @TaskLocal public static var current: StyleRegistry?

    /// Bind `registry` as `current` for one render/reconcile. SwiftWeb page,
    /// action, stream, and client render paths must bind a registry so typed
    /// styles serialize as classes and CSS is emitted through the stylesheet
    /// channel. A nil binding is only for low-level isolated SwiftHTML rendering.
    @discardableResult
    public static func withCurrent<R>(_ registry: StyleRegistry?, _ body: () throws -> R) rethrows -> R {
        let transformer: (any HTMLAttributeTransformer)? = registry.map {
            AtomicStyleAttributeTransformer(registry: $0)
        }
        return try EnlargedStackContext.withValue(StyleRegistryContext(registry: registry)) {
            try HTMLAttributeTransformContext.withValue(transformer) {
                try $current.withValue(registry, operation: body)
            }
        }
    }

    /// Register a `Style`'s declarations as atomic classes and return the space-joined
    /// class names. Each declaration is validated first: a value that could escape its
    /// rule inside a `<style>` block fails loudly and is never injected verbatim.
    public func register(_ style: Style) -> String {
        var names: [String] = []
        for declaration in style.declarations {
            Self.validate(property: declaration.property, value: declaration.value)
            let name = Self.className(property: declaration.property, value: declaration.value)
            let body = "\(declaration.property): \(declaration.value)"
            collected.withLock { store in
                if let existing = store.bodies[name] {
                    precondition(existing == body, "Atomic CSS class collision: \(name)")
                } else {
                    store.bodies[name] = body
                    store.order.append(name)
                }
            }
            names.append(name)
        }
        return names.joined(separator: " ")
    }

    /// Every collected rule in first-seen (declaration) order, for emission into a
    /// `<style>` block.
    public func rules() -> [(className: String, body: String)] {
        collected.withLock { store in
            store.order.map { ($0, store.bodies[$0]!) }
        }
    }

    public func registerStylesheet(_ css: String) {
        guard !css.isEmpty else { return }
        collected.withLock { store in
            if store.stylesheets.insert(css).inserted {
                store.stylesheetOrder.append(css)
            }
        }
    }

    public func stylesheets() -> [String] {
        collected.withLock { $0.stylesheetOrder }
    }

    public func registerScript(id: String, body: String) {
        guard !id.isEmpty, !body.isEmpty else { return }
        collected.withLock { store in
            if let existing = store.scripts[id] {
                precondition(existing == body, "Head script id collision: \(id)")
            } else {
                store.scripts[id] = body
                store.scriptOrder.append(id)
            }
        }
    }

    public func scripts() -> [(id: String, body: String)] {
        collected.withLock { store in
            store.scriptOrder.map { ($0, store.scripts[$0]!) }
        }
    }

    // MARK: - Validation
    // Reject anything that could close a rule or inject a new selector once the value
    // moves from an inline attribute into a `<style>` block.

    public static func isSafe(property: String, value: String) -> Bool {
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

    public static func isSafe(_ style: Style) -> Bool {
        style.declarations.allSatisfy { declaration in
            isSafe(property: declaration.property, value: declaration.value)
        }
    }

    public static func validate(_ style: Style) {
        for declaration in style.declarations {
            validate(property: declaration.property, value: declaration.value)
        }
    }

    private static func validate(property: String, value: String) {
        guard isSafe(property: property, value: value) else {
            preconditionFailure("Rejected unsafe CSS declaration: \(property): \(value)")
        }
    }

    // MARK: - Class name
    // Pure function of the canonical (property, value-with-unit) so the server and the
    // WASM client compute the same class for the same declaration -> automatic dedup.

    public static func className(property: String, value: String) -> String {
        let prefix = abbreviation(for: property)
        let hash = fnv1a(property + ":" + value)
        if let encoded = encode(value), encoded.count <= 16 {
            return "swui-\(prefix)-\(encoded)-x\(hash)"
        }
        return "swui-\(prefix)-x\(hash)"
    }

    private static let abbreviations: [String: String] = [
        "width": "w", "height": "h", "min-width": "minw", "max-width": "maxw",
        "min-height": "minh", "max-height": "maxh", "padding": "p", "margin": "m",
        "border-radius": "r", "opacity": "o", "color": "c", "background": "bg",
        "background-color": "bgc", "box-shadow": "shadow", "flex-grow": "grow",
        "justify-content": "jc", "align-items": "ai", "text-align": "ta",
    ]

    private static func abbreviation(for property: String) -> String {
        if let abbreviation = abbreviations[property] { return abbreviation }
        let abbreviation = String(property.filter { $0.isLetter || $0.isNumber })
        return abbreviation.isEmpty ? "x" : abbreviation
    }

    /// Canonicalize a value into an identifier-safe token, preserving unit so `13px`
    /// and `13em` differ. Returns `nil` when the value is not simple (use the hash path).
    private static func encode(_ value: String) -> String? {
        var out = ""
        for character in value {
            switch character {
            case "a"..."z", "A"..."Z", "0"..."9": out.append(character)
            case ".": out.append("_")
            case "%": out.append("pct")
            case "-": out.append("n")
            default: return nil
            }
        }
        return out.isEmpty ? nil : out
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
/// `class` attribute. SwiftWeb renderers bind the registry before rendering; the no-registry
/// branch exists only for low-level isolated SwiftHTML rendering where there is no stylesheet
/// collector to receive atomic rules.
public func atom(_ style: Style) -> HTMLAttribute {
    guard !style.isEmpty else { return .class("") }
    if let registry = StyleRegistry.current {
        return .class(registry.register(style))
    }
    StyleRegistry.validate(style)
    return .style(style)
}

private struct StyleRegistryContext: EnlargedStackContextPropagator {
    let registry: StyleRegistry?

    func apply<Result>(_ operation: () throws -> Result) rethrows -> Result {
        let transformer: (any HTMLAttributeTransformer)? = registry.map {
            AtomicStyleAttributeTransformer(registry: $0)
        }
        return try HTMLAttributeTransformContext.withValue(transformer) {
            try StyleRegistry.$current.withValue(registry, operation: operation)
        }
    }
}

private struct AtomicStyleAttributeTransformer: HTMLAttributeTransformer {
    let registry: StyleRegistry

    func transform(_ attributes: [HTMLAttribute]) -> [HTMLAttribute] {
        var classTokens: [String] = []
        var remaining: [HTMLAttribute] = []
        remaining.reserveCapacity(attributes.count)

        for attribute in attributes {
            switch attribute.name {
            case "class":
                if let value = attribute.value, !value.isEmpty {
                    classTokens.append(value)
                }
            case "style":
                if let style = attribute.style {
                    let className = registry.register(style)
                    if !className.isEmpty {
                        classTokens.append(className)
                    }
                } else {
                    preconditionFailure("String style attributes are not supported inside SwiftWeb render scopes")
                }
            default:
                remaining.append(attribute)
            }
        }

        guard !classTokens.isEmpty else {
            return remaining
        }
        return [.class(classTokens.joined(separator: " "))] + remaining
    }
}
