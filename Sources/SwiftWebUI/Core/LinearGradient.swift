import Foundation

/// A linear gradient style that lowers to a CSS `linear-gradient()`, mirroring
/// SwiftUI's `LinearGradient(colors:startPoint:endPoint:)`. Usable anywhere a
/// `WebShapeStyle` is accepted (e.g. `.background(_:)`, `.foregroundStyle(_:)`).
public struct LinearGradient: WebShapeStyle, Sendable {
    private let colors: [CSSShapeStyle]
    private let startPoint: UnitPoint
    private let endPoint: UnitPoint

    public init(colors: [CSSShapeStyle], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        // CSS gradient angle: 0deg points up and increases clockwise; the gradient
        // line runs start -> end in a y-down coordinate space.
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let raw = atan2(dx, -dy) * 180 / .pi
        let angle = raw < 0 ? raw + 360 : raw
        let stops = colors
            .map { $0.resolve(in: context).cssValue }
            .joined(separator: ", ")
        return ResolvedStyle(cssValue: "linear-gradient(\(trimmedNumber(angle))deg, \(stops))")
    }
}
