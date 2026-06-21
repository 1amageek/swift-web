func styleSystemCSSValue<ShapeStyle: WebShapeStyle>(_ style: ShapeStyle) -> String {
    style.resolve(in: .default).cssValue
}

public struct StyleSystemBorder: Sendable, Equatable, Codable {
    let cssValue: String

    init(_ cssValue: String) {
        self.cssValue = cssValue
    }

    public static let none = StyleSystemBorder("none")

    public static func solid<ShapeStyle: WebShapeStyle>(width: Length = 1, color: ShapeStyle) -> StyleSystemBorder {
        StyleSystemBorder("\(width.cssValue) solid \(styleSystemCSSValue(color))")
    }
}

public struct StyleSystemShadow: Sendable, Equatable, Codable {
    public struct Layer: Sendable, Equatable, Codable {
        let cssValue: String

        init(_ cssValue: String) {
            self.cssValue = cssValue
        }

        public static func drop(
            x: Length = 0,
            y: Length,
            blur: Length,
            spread: Length? = nil,
            color: some WebShapeStyle
        ) -> Layer {
            Layer(shadowValue(prefix: nil, x: x, y: y, blur: blur, spread: spread, color: color))
        }

        public static func inset(
            x: Length = 0,
            y: Length,
            blur: Length,
            spread: Length? = nil,
            color: some WebShapeStyle
        ) -> Layer {
            Layer(shadowValue(prefix: "inset", x: x, y: y, blur: blur, spread: spread, color: color))
        }
    }

    let cssValue: String

    init(_ cssValue: String) {
        self.cssValue = cssValue
    }

    public static let none = StyleSystemShadow("none")

    public static func layers(_ layers: [Layer]) -> StyleSystemShadow {
        StyleSystemShadow(layers.map(\.cssValue).joined(separator: ", "))
    }

    public static func drop(
        x: Length = 0,
        y: Length,
        blur: Length,
        spread: Length? = nil,
        color: some WebShapeStyle
    ) -> StyleSystemShadow {
        layers([.drop(x: x, y: y, blur: blur, spread: spread, color: color)])
    }
}

public enum StyleSystemTextDecoration: String, Sendable, Equatable, Codable {
    case none
    case underline

    var cssValue: String { rawValue }
}

public struct StyleSystemIntrinsicSize: Sendable, Equatable, Codable {
    let cssValue: String

    init(_ cssValue: String) {
        self.cssValue = cssValue
    }

    public static func automatic(block: Length) -> StyleSystemIntrinsicSize {
        StyleSystemIntrinsicSize("auto \(block.cssValue)")
    }
}

public struct StyleSystemMotionTiming: Sendable, Equatable, Codable {
    public enum Curve: Sendable, Equatable, Codable {
        case ease
        case cubicBezier(Double, Double, Double, Double)

        var cssValue: String {
            switch self {
            case .ease:
                "ease"
            case .cubicBezier(let x1, let y1, let x2, let y2):
                "cubic-bezier(\(trimmedNumber(x1)), \(trimmedNumber(y1)), \(trimmedNumber(x2)), \(trimmedNumber(y2)))"
            }
        }
    }

    let cssValue: String

    public init(milliseconds: Int, curve: Curve) {
        cssValue = "\(milliseconds)ms \(curve.cssValue)"
    }
}

public struct StyleSystemRefraction: Sendable, Equatable, Codable {
    let cssValue: String

    init(_ cssValue: String) {
        self.cssValue = cssValue
    }

    public static let none = StyleSystemRefraction("none")

    public static func svgFilter(id: String) -> StyleSystemRefraction {
        StyleSystemRefraction("url(\"#\(id)\")")
    }
}

private func shadowValue<ShapeStyle: WebShapeStyle>(
    prefix: String?,
    x: Length,
    y: Length,
    blur: Length,
    spread: Length?,
    color: ShapeStyle
) -> String {
    var parts: [String] = []
    if let prefix {
        parts.append(prefix)
    }
    parts.append(x.cssValue)
    parts.append(y.cssValue)
    parts.append(blur.cssValue)
    if let spread {
        parts.append(spread.cssValue)
    }
    parts.append(styleSystemCSSValue(color))
    return parts.joined(separator: " ")
}
