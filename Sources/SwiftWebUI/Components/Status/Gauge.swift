import SwiftHTML

/// A view that shows a value within a range, mirroring SwiftUI `Gauge`.
///
/// Lowers to a native `<meter>` element. The meter track composes the shared
/// ultra-thin material so its fill tracks the active design style.
public struct Gauge<Label: HTML>: WebUIAttributeComponent {
    private let value: Double
    private let bounds: ClosedRange<Double>
    private let label: Label
    private let attributes: [HTMLAttribute]
    @Environment(\.gaugeStyle) private var gaugeStyle

    public init(
        value: Double,
        in bounds: ClosedRange<Double> = 0...1,
        @HTMLBuilder label: () -> Label
    ) {
        self.init(value: value, bounds: bounds, label: label(), attributes: [])
    }

    private init(
        value: Double,
        bounds: ClosedRange<Double>,
        label: Label,
        attributes: [HTMLAttribute]
    ) {
        self.value = value
        self.bounds = bounds
        self.label = label
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName("swui-gauge", gaugeStyle.className),
                extra: attributes
            )
        ) {
            span(.class("swui-gauge-label")) {
                label
            }
            // `<meter>` is a replaced element: the material's `::before`
            // rim/refraction overlay does not paint here, but its fill and
            // backdrop blur (the track) still apply.
            Element(
                "meter",
                attributes: [
                    .class("swui-gauge-meter \(MaterialClass.material) \(MaterialClass.ultraThin)"),
                    styleAttribute(.custom("--swui-material-tint", "var(--swui-field-background)")),
                    .min(bounds.lowerBound),
                    .max(bounds.upperBound),
                    .value(value),
                ],
                isVoid: false
            ) {}
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value: value, bounds: bounds, label: label, attributes: self.attributes + attributes)
    }
}

public extension Gauge where Label == text {
    /// Creates a gauge whose label is plain inline text.
    init(value: Double, in bounds: ClosedRange<Double> = 0...1, label: String) {
        self.init(value: value, in: bounds) {
            text(label)
        }
    }
}
