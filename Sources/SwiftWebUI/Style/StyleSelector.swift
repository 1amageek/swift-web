import SwiftHTML

public struct StyleSelector: Sendable, Equatable, Hashable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "Style selector cannot be empty")
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }

    public var cssSelector: CSSSelector {
        CSSSelector(rawValue)
    }

    public static var universal: Self {
        Self("*")
    }

    public static func element(_ element: StyleElement) -> Self {
        Self(element.rawValue)
    }

    public static func `class`(_ className: StyleClass) -> Self {
        Self(".\(StyleClass.escapedIdentifier(className.rawValue))")
    }

    public static func attribute(_ name: String, equals value: String? = nil) -> Self {
        StyleAttributeSelector(name: name, value: value).selector
    }

    public static func pseudo(_ pseudoClass: StylePseudoClass) -> Self {
        Self(":\(pseudoClass.rawValue)")
    }

    public static func list(_ selectors: [Self]) -> Self {
        precondition(!selectors.isEmpty, "Selector list cannot be empty")
        return Self(selectors.map(\.rawValue).joined(separator: ",\n"))
    }

    public static func list(_ selectors: Self...) -> Self {
        list(selectors)
    }

    public func compound(_ selector: Self) -> Self {
        Self(rawValue + selector.rawValue)
    }

    public func descendant(_ selector: Self) -> Self {
        Self("\(rawValue) \(selector.rawValue)")
    }

    public func child(_ selector: Self) -> Self {
        Self("\(rawValue) > \(selector.rawValue)")
    }

    public func adjacentSibling(_ selector: Self) -> Self {
        Self("\(rawValue) + \(selector.rawValue)")
    }

    public func generalSibling(_ selector: Self) -> Self {
        Self("\(rawValue) ~ \(selector.rawValue)")
    }

    public func attribute(_ name: String, equals value: String? = nil) -> Self {
        compound(.attribute(name, equals: value))
    }

    public func pseudo(_ pseudoClass: StylePseudoClass) -> Self {
        Self("\(rawValue):\(pseudoClass.rawValue)")
    }

    public func pseudoElement(_ pseudoElement: StylePseudoElement) -> Self {
        Self("\(rawValue)::\(pseudoElement.rawValue)")
    }

    public func not(_ selector: Self) -> Self {
        Self("\(rawValue):not(\(selector.rawValue))")
    }

    public func has(_ selector: Self) -> Self {
        Self("\(rawValue):has(\(selector.rawValue))")
    }

    public func hasChild(_ selector: Self) -> Self {
        Self("\(rawValue):has(> \(selector.rawValue))")
    }

    func replacingSelfReference(in selector: String) -> Self {
        StyleSelector(selector.replacingOccurrences(of: "&", with: rawValue))
    }
}

public enum StyleElement: String, Sendable, Equatable, Hashable {
    case body
    case button
    case html
    case input
    case select
    case small
    case strong
    case textarea
}

public enum StylePseudoClass: String, Sendable, Equatable, Hashable {
    case active
    case checked
    case disabled
    case empty
    case firstChild = "first-child"
    case focus
    case focusVisible = "focus-visible"
    case focusWithin = "focus-within"
    case hover
    case invalid
    case lastChild = "last-child"
    case link
    case open
    case placeholderShown = "placeholder-shown"
    case visited
}

public enum StylePseudoElement: String, Sendable, Equatable, Hashable {
    case after
    case backdrop
    case before
    case mozColorSwatch = "-moz-color-swatch"
    case mozMeterBar = "-moz-meter-bar"
    case mozProgressBar = "-moz-progress-bar"
    case mozRangeThumb = "-moz-range-thumb"
    case placeholder
    case selection
    case webkitColorSwatch = "-webkit-color-swatch"
    case webkitColorSwatchWrapper = "-webkit-color-swatch-wrapper"
    case webkitDetailsMarker = "-webkit-details-marker"
    case webkitMeterBar = "-webkit-meter-bar"
    case webkitMeterEvenLessGoodValue = "-webkit-meter-even-less-good-value"
    case webkitMeterOptimumValue = "-webkit-meter-optimum-value"
    case webkitMeterSuboptimumValue = "-webkit-meter-suboptimum-value"
    case webkitProgressBar = "-webkit-progress-bar"
    case webkitProgressValue = "-webkit-progress-value"
    case webkitScrollbar = "-webkit-scrollbar"
    case webkitSliderThumb = "-webkit-slider-thumb"
}

public func rule(_ selector: StyleSelector, @StyleBuilder _ style: () -> Style) -> CSSRule {
    CSSRule(selector.cssSelector, style: style())
}

public func rule(_ selector: StyleSelector, _ style: Style) -> CSSRule {
    CSSRule(selector.cssSelector, style: style)
}

private struct StyleAttributeSelector {
    let name: String
    let value: String?

    var selector: StyleSelector {
        guard Self.isValidAttributeName(name) else {
            preconditionFailure("Invalid CSS attribute selector name: \(name)")
        }
        if let value {
            return StyleSelector("[\(name)=\"\(Self.escapeString(value))\"]")
        }
        return StyleSelector("[\(name)]")
    }

    private static func isValidAttributeName(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        guard first.isLetter || first == "_" || first == "-" else { return false }
        return value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_" || character == "-" || character == ":"
        }
    }

    private static func escapeString(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22:
                escaped.append("\\22 ")
            case 0x5C:
                escaped.append("\\5C ")
            case 0x0A:
                escaped.append("\\A ")
            case 0x0C:
                escaped.append("\\C ")
            case 0x0D:
                escaped.append("\\D ")
            default:
                if scalar.value >= 0x20 && scalar.value <= 0x7E {
                    escaped.unicodeScalars.append(scalar)
                } else {
                    escaped.append("\\")
                    escaped.append(String(scalar.value, radix: 16, uppercase: true))
                    escaped.append(" ")
                }
            }
        }
        return escaped
    }
}
