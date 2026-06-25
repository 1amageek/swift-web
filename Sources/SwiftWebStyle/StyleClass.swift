import SwiftHTML

public struct StyleClass: Sendable, Equatable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(Self.isValid(rawValue), "Invalid CSS class token: \(rawValue)")
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String {
        rawValue
    }

    public var selector: StyleSelector {
        .class(self)
    }

    public var cssSelector: CSSSelector {
        selector.cssSelector
    }

    public var attribute: HTMLAttribute {
        .class(rawValue)
    }

    public static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let disallowed: Set<Character> = ["<", ">", "\"", "'", "`"]
        return !value.contains { character in
            character.isWhitespace || character.unicodeScalars.contains { $0.value < 0x20 } || disallowed.contains(character)
        }
    }

    static func escapedIdentifier(_ value: String) -> String {
        let scalars = Array(value.unicodeScalars)
        var result = ""
        for index in scalars.indices {
            let scalar = scalars[index]
            if canUseUnescaped(scalar, at: index, in: scalars) {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("\\")
                result.append(String(scalar.value, radix: 16))
                result.append(" ")
            }
        }
        return result
    }

    private static func canUseUnescaped(_ scalar: UnicodeScalar, at index: Int, in scalars: [UnicodeScalar]) -> Bool {
        let value = scalar.value
        let isLetter = (65...90).contains(value) || (97...122).contains(value)
        let isDigit = (48...57).contains(value)
        let isIdentifierPunctuation = value == 45 || value == 95

        if index == scalars.startIndex {
            return isLetter || value == 95 || (value == 45 && scalars.count > 1)
        }

        if index == scalars.index(after: scalars.startIndex), scalars.first?.value == 45 {
            return !isDigit && (isLetter || isIdentifierPunctuation)
        }

        return isLetter || isDigit || isIdentifierPunctuation
    }
}

public func rule(_ className: StyleClass, @StyleBuilder _ style: () -> Style) -> Stylesheet {
    StyleUtilityRule(className: className).stylesheet(for: style())
}

public func rule(_ className: StyleClass, _ style: Style) -> Stylesheet {
    StyleUtilityRule(className: className).stylesheet(for: style)
}

public extension HTMLAttribute {
    static func `class`(_ className: StyleClass) -> HTMLAttribute {
        className.attribute
    }
}
