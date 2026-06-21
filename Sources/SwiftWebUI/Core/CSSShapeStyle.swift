public struct CSSShapeStyle: WebShapeStyle, Sendable, Equatable {
    public let value: String

    init(_ value: String) {
        self.value = value
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        ResolvedStyle(cssValue: value)
    }
}

public extension WebShapeStyle where Self == CSSShapeStyle {
    static var clear: CSSShapeStyle {
        CSSShapeStyle("transparent")
    }

    static var white: CSSShapeStyle {
        CSSShapeStyle("#ffffff")
    }

    static var black: CSSShapeStyle {
        CSSShapeStyle("#000000")
    }

    static func hex(_ value: Int) -> CSSShapeStyle {
        let clamped = max(0, min(value, 0xFF_FF_FF))
        let hex = String(clamped, radix: 16, uppercase: false)
        return CSSShapeStyle("#\(String(repeating: "0", count: 6 - hex.count))\(hex)")
    }

    static func rgba(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Double) -> CSSShapeStyle {
        CSSShapeStyle("rgba(\(red), \(green), \(blue), \(trimmedNumber(alpha)))")
    }
}
