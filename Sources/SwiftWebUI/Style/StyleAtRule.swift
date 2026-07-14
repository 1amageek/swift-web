import SwiftHTML

public struct StyleMediaQuery: Sendable, Equatable, Hashable, CustomStringConvertible {
    let cssText: String

    private init(_ cssText: String) {
        precondition(Self.isSafePrelude(cssText), "Invalid media query: \(cssText)")
        self.cssText = cssText
    }

    public var description: String {
        cssText
    }

    public static func minWidth(_ width: String) -> Self {
        Self("(min-width: \(width))")
    }

    public static func maxWidth(_ width: String) -> Self {
        Self("(max-width: \(width))")
    }

    public static func prefersColorScheme(_ scheme: StyleColorSchemePreference) -> Self {
        Self("(prefers-color-scheme: \(scheme.rawValue))")
    }

    public static func prefersReducedMotion(_ preference: StyleReducedPreference) -> Self {
        Self("(prefers-reduced-motion: \(preference.rawValue))")
    }

    public static func prefersReducedTransparency(_ preference: StyleReducedPreference) -> Self {
        Self("(prefers-reduced-transparency: \(preference.rawValue))")
    }

    static func isSafePrelude(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let unsafe: Set<Character> = ["{", "}", "<", ">", ";", "\\"]
        let hasControl = value.unicodeScalars.contains { $0.value < 0x20 }
        return !hasControl
            && !value.contains(where: { unsafe.contains($0) })
            && !value.containsSubstring("/*")
            && !value.containsSubstring("*/")
    }
}

public enum StyleColorSchemePreference: String, Sendable, Equatable, Hashable {
    case dark
    case light
}

public enum StyleReducedPreference: String, Sendable, Equatable, Hashable {
    case noPreference = "no-preference"
    case reduce
}

public struct StyleSupportsCondition: Sendable, Equatable, Hashable, CustomStringConvertible {
    let cssText: String

    private init(_ cssText: String) {
        precondition(StyleMediaQuery.isSafePrelude(cssText), "Invalid supports condition: \(cssText)")
        self.cssText = cssText
    }

    public var description: String {
        cssText
    }

    public static func not(_ condition: Self) -> Self {
        Self("not (\(condition.cssText))")
    }

    public static func backdropFilterBlurAvailable() -> Self {
        Self("(backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))")
    }
}

public struct StyleContainerQuery: Sendable, Equatable, Hashable, CustomStringConvertible {
    let cssText: String

    private init(_ cssText: String) {
        precondition(StyleMediaQuery.isSafePrelude(cssText), "Invalid container query: \(cssText)")
        self.cssText = cssText
    }

    public var description: String {
        cssText
    }

    public static func minWidth(_ width: String, name: String? = nil) -> Self {
        Self(Self.query(name: name, condition: "(min-width: \(width))"))
    }

    public static func maxWidth(_ width: String, name: String? = nil) -> Self {
        Self(Self.query(name: name, condition: "(max-width: \(width))"))
    }

    private static func query(name: String?, condition: String) -> String {
        guard let name, !name.isEmpty else { return condition }
        precondition(StyleClass.isValid(name), "Invalid container name: \(name)")
        return "\(name) \(condition)"
    }
}

public func media(_ query: StyleMediaQuery, @StylesheetBuilder _ content: () -> Stylesheet) -> StylesheetItem {
    .media(query.cssText, content())
}

public func supports(_ condition: StyleSupportsCondition, @StylesheetBuilder _ content: () -> Stylesheet) -> StylesheetItem {
    .supports(condition.cssText, content())
}

public func container(_ query: StyleContainerQuery, @StylesheetBuilder _ content: () -> Stylesheet) -> StylesheetItem {
    .container(query.cssText, content())
}
