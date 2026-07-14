import SwiftHTML

public enum StyleVariant: Sendable, Equatable, Hashable {
    case pseudo(StylePseudoClass)
    case pseudoElement(StylePseudoElement)
    case dark
    case breakpoint(StyleBreakpoint)
    case maxBreakpoint(StyleBreakpoint)
    case container(StyleBreakpoint, name: String?)
    case maxContainer(StyleBreakpoint, name: String?)
    case arbitraryContainer(width: String, name: String?, isMax: Bool)
    case group(name: String?, StylePseudoClass)
    case peer(name: String?, StylePseudoClass)
    case data(name: String, value: String?)
    case aria(name: String, value: String?)
    case has(StylePseudoClass)
    case not(StylePseudoClass)
    case arbitrarySelector(String)
    case child
    case descendant
}

public struct StyleBreakpoint: Sendable, Equatable, Hashable {
    public let name: String
    public let minWidth: String

    public init(name: String, minWidth: String) {
        precondition(StyleClass.isValid(name), "Invalid breakpoint name: \(name)")
        precondition(!minWidth.isEmpty, "Breakpoint min-width cannot be empty")
        self.name = name
        self.minWidth = minWidth
    }

    public static let sm = Self(name: "sm", minWidth: "640px")
    public static let md = Self(name: "md", minWidth: "768px")
    public static let lg = Self(name: "lg", minWidth: "1024px")
    public static let xl = Self(name: "xl", minWidth: "1280px")
    public static let twoXL = Self(name: "2xl", minWidth: "1536px")

    static let defaults: [String: Self] = [
        sm.name: sm,
        md.name: md,
        lg.name: lg,
        xl.name: xl,
        twoXL.name: twoXL,
    ]
}

struct StyleUtilityRule: Sendable, Equatable {
    var className: StyleClass
    var baseToken: String
    var variants: [StyleVariant]

    init(className: StyleClass) {
        self.className = className
        let parsed = Self.parseToken(className.rawValue)
        self.baseToken = parsed.baseToken
        self.variants = parsed.variants
    }

    func stylesheet(for style: Style) -> Stylesheet {
        var selector = StyleSelector.class(className)
        var mediaQueries: [StyleMediaQuery] = []
        var containerQueries: [StyleContainerQuery] = []

        for variant in variants {
            switch variant {
            case .pseudo(let pseudoClass):
                selector = selector.pseudo(pseudoClass)
            case .pseudoElement(let pseudoElement):
                selector = selector.pseudoElement(pseudoElement)
            case .dark:
                selector = StyleSelector
                    .class("swui-root")
                    .attribute("data-color-scheme", equals: "dark")
                    .descendant(selector)
            case .breakpoint(let breakpoint):
                mediaQueries.append(.minWidth(breakpoint.minWidth))
            case .maxBreakpoint(let breakpoint):
                mediaQueries.append(.maxWidth(breakpoint.maxWidthQueryValue))
            case .container(let breakpoint, let name):
                containerQueries.append(.minWidth(breakpoint.minWidth, name: name))
            case .maxContainer(let breakpoint, let name):
                containerQueries.append(.maxWidth(breakpoint.maxWidthQueryValue, name: name))
            case .arbitraryContainer(let width, let name, let isMax):
                containerQueries.append(isMax ? .maxWidth(width, name: name) : .minWidth(width, name: name))
            case .group(let name, let pseudoClass):
                let groupClass = name.map { "group/\($0)" } ?? "group"
                selector = StyleSelector
                    .class(StyleClass(groupClass))
                    .pseudo(pseudoClass)
                    .descendant(selector)
            case .peer(let name, let pseudoClass):
                let peerClass = name.map { "peer/\($0)" } ?? "peer"
                selector = StyleSelector
                    .class(StyleClass(peerClass))
                    .pseudo(pseudoClass)
                    .generalSibling(selector)
            case .data(let name, let value):
                selector = selector.attribute("data-\(name)", equals: value)
            case .aria(let name, let value):
                selector = selector.attribute("aria-\(name)", equals: value ?? "true")
            case .has(let pseudoClass):
                selector = selector.has(.pseudo(pseudoClass))
            case .not(let pseudoClass):
                selector = selector.not(.pseudo(pseudoClass))
            case .arbitrarySelector(let value):
                selector = selector.replacingSelfReference(in: value)
            case .child:
                selector = selector.child(.universal)
            case .descendant:
                selector = selector.descendant(.universal)
            }
        }

        var stylesheet = Stylesheet(rule(selector, style))
        for query in containerQueries.reversed() {
            stylesheet = Stylesheet(items: [.container(query.cssText, stylesheet)])
        }
        for query in mediaQueries.reversed() {
            stylesheet = Stylesheet(items: [.media(query.cssText, stylesheet)])
        }
        return stylesheet
    }

    private static func parseToken(_ token: String) -> (baseToken: String, variants: [StyleVariant]) {
        let parts = splitVariantToken(token)
        guard parts.count > 1 else { return (token, []) }
        let variants = parts.dropLast().map { part in
            guard let variant = StyleVariant(token: part) else {
                preconditionFailure("Unknown style utility variant: \(part)")
            }
            return variant
        }
        return (parts.last ?? token, variants)
    }

    private static func splitVariantToken(_ token: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var bracketDepth = 0

        for character in token {
            switch character {
            case "[":
                bracketDepth += 1
                current.append(character)
            case "]":
                bracketDepth = max(0, bracketDepth - 1)
                current.append(character)
            case ":" where bracketDepth == 0:
                parts.append(current)
                current = ""
            default:
                current.append(character)
            }
        }

        parts.append(current)
        return parts
    }
}

private extension StyleVariant {
    init?(token: String) {
        switch token {
        case "*":
            self = .child
        case "**":
            self = .descendant
        case "hover":
            self = .pseudo(.hover)
        case "focus":
            self = .pseudo(.focus)
        case "focus-visible":
            self = .pseudo(.focusVisible)
        case "focus-within":
            self = .pseudo(.focusWithin)
        case "active":
            self = .pseudo(.active)
        case "visited":
            self = .pseudo(.visited)
        case "disabled":
            self = .pseudo(.disabled)
        case "checked":
            self = .pseudo(.checked)
        case "invalid":
            self = .pseudo(.invalid)
        case "open":
            self = .pseudo(.open)
        case "first":
            self = .pseudo(.firstChild)
        case "last":
            self = .pseudo(.lastChild)
        case "empty":
            self = .pseudo(.empty)
        case "placeholder":
            self = .pseudoElement(.placeholder)
        case "selection":
            self = .pseudoElement(.selection)
        case "before":
            self = .pseudoElement(.before)
        case "after":
            self = .pseudoElement(.after)
        case "dark":
            self = .dark
        default:
            if token.hasPrefix("[") && token.hasSuffix("]") {
                let selector = String(token.dropFirst().dropLast())
                guard StyleArbitrarySelector.isValid(selector) else { return nil }
                self = .arbitrarySelector(selector)
            } else if let container = Self.containerVariant(token: token) {
                self = container
            } else if let group = Self.prefixedPseudo(token: token, prefix: "group-") {
                self = .group(name: group.name, group.pseudoClass)
            } else if let peer = Self.prefixedPseudo(token: token, prefix: "peer-") {
                self = .peer(name: peer.name, peer.pseudoClass)
            } else if token.hasPrefix("data-") {
                guard let attribute = Self.attributeVariant(token: String(token.dropFirst(5))) else { return nil }
                self = .data(name: attribute.name, value: attribute.value)
            } else if token.hasPrefix("aria-") {
                guard let attribute = Self.attributeVariant(token: String(token.dropFirst(5))) else { return nil }
                self = .aria(name: attribute.name, value: attribute.value)
            } else if let pseudoClass = Self.prefixedBarePseudo(token: token, prefix: "has-") {
                self = .has(pseudoClass)
            } else if let pseudoClass = Self.prefixedBarePseudo(token: token, prefix: "not-") {
                self = .not(pseudoClass)
            } else if let breakpoint = StyleBreakpoint.defaults[token] {
                self = .breakpoint(breakpoint)
            } else if token.hasPrefix("max-") {
                let name = String(token.dropFirst(4))
                guard let breakpoint = StyleBreakpoint.defaults[name] else { return nil }
                self = .maxBreakpoint(breakpoint)
            } else {
                return nil
            }
        }
    }

    static func prefixedBarePseudo(token: String, prefix: String) -> StylePseudoClass? {
        guard token.hasPrefix(prefix) else { return nil }
        let name = String(token.dropFirst(prefix.count))
        return pseudoClass(token: name)
    }

    static func prefixedPseudo(token: String, prefix: String) -> (pseudoClass: StylePseudoClass, name: String?)? {
        guard token.hasPrefix(prefix) else { return nil }
        let value = String(token.dropFirst(prefix.count))
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard let pseudoClass = pseudoClass(token: parts[0]) else { return nil }
        if parts.count == 2 {
            guard StyleClass.isValid(parts[1]) else { return nil }
            return (pseudoClass, parts[1])
        }
        return (pseudoClass, nil)
    }

    static func attributeVariant(token: String) -> (name: String, value: String?)? {
        if token.hasPrefix("[") && token.hasSuffix("]") {
            let content = String(token.dropFirst().dropLast())
            let parts = content.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  StyleAttributeVariantName.isValid(parts[0]),
                  StyleAttributeVariantName.isSafeValue(parts[1])
            else {
                return nil
            }
            return (parts[0], parts[1])
        }

        guard StyleAttributeVariantName.isValid(token) else { return nil }
        return (token, nil)
    }

    static func containerVariant(token: String) -> StyleVariant? {
        guard token.hasPrefix("@") else { return nil }
        let value = String(token.dropFirst())
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        let query = parts[0]
        let name = parts.count == 2 ? parts[1] : nil
        if let name, !StyleClass.isValid(name) { return nil }

        if let breakpoint = StyleBreakpoint.defaults[query] {
            return .container(breakpoint, name: name)
        }

        if query.hasPrefix("max-") {
            let breakpointName = String(query.dropFirst(4))
            if let breakpoint = StyleBreakpoint.defaults[breakpointName] {
                return .maxContainer(breakpoint, name: name)
            }
            if let width = bracketedValue(String(query.dropFirst(4))) {
                return .arbitraryContainer(width: width, name: name, isMax: true)
            }
            return nil
        }

        if query.hasPrefix("min-"), let width = bracketedValue(String(query.dropFirst(4))) {
            return .arbitraryContainer(width: width, name: name, isMax: false)
        }

        return nil
    }

    static func bracketedValue(_ token: String) -> String? {
        guard token.hasPrefix("[") && token.hasSuffix("]") else { return nil }
        let value = String(token.dropFirst().dropLast()).replacingOccurrences(of: "_", with: " ")
        guard StyleRegistry.isSafe(property: "width", value: value) else { return nil }
        return value
    }

    static func pseudoClass(token: String) -> StylePseudoClass? {
        switch token {
        case "hover": return .hover
        case "focus": return .focus
        case "focus-visible": return .focusVisible
        case "focus-within": return .focusWithin
        case "active": return .active
        case "visited": return .visited
        case "disabled": return .disabled
        case "checked": return .checked
        case "invalid": return .invalid
        case "open": return .open
        case "first": return .firstChild
        case "last": return .lastChild
        case "empty": return .empty
        default: return nil
        }
    }
}

private enum StyleAttributeVariantName {
    static func isValid(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        guard first.isLetter || first == "_" || first == "-" else { return false }
        return value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }
    }

    static func isSafeValue(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let unsafe: Set<Character> = ["{", "}", "<", ">", ";", "\"", "'", "`", "\\"]
        let hasControl = value.unicodeScalars.contains { $0.value < 0x20 }
        return !hasControl && !value.contains(where: { unsafe.contains($0) })
    }
}

private enum StyleArbitrarySelector {
    static func isValid(_ value: String) -> Bool {
        guard value.contains("&") else { return false }
        let unsafe: Set<Character> = ["{", "}", "<", ">", ";", "@", "\\"]
        let hasControl = value.unicodeScalars.contains { $0.value < 0x20 }
        return !hasControl
            && !value.contains(where: { unsafe.contains($0) })
            && !value.containsSubstring("/*")
            && !value.containsSubstring("*/")
    }
}

private extension StyleBreakpoint {
    var maxWidthQueryValue: String {
        guard minWidth.hasSuffix("px"),
              let width = Double(minWidth.dropLast(2))
        else {
            return minWidth
        }
        return "\(trimmed(width - 0.02))px"
    }

    private func trimmed(_ value: Double) -> String {
        // Round to two decimals and print the shortest form, matching the old
        // "%.2f then strip trailing zeros" without Foundation's String(format:).
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}
