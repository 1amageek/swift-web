import SwiftHTML

public struct Slider: WebUIAttributeComponent {
    private let value: Binding<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "input",
            attributes: mergedAttributes(
                class: "swui-slider \(controlSize.className) \(LayoutClass.fillHorizontal)",
                extra: inputAttributes
            ),
            isVoid: true
        )
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value: value, bounds: bounds, step: step, attributes: self.attributes + attributes)
    }

    private init(
        value: Binding<Double>,
        bounds: ClosedRange<Double>,
        step: Double?,
        attributes: [HTMLAttribute]
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.attributes = attributes
    }

    private var inputAttributes: [HTMLAttribute] {
        let value = self.value
        var result: [HTMLAttribute] = [
            .type(.range),
            .value(value.wrappedValue),
            .min(bounds.lowerBound),
            .max(bounds.upperBound),
            .onInput { event in
                guard let rawValue = event.value,
                      let doubleValue = Double(rawValue)
                else {
                    return
                }
                value.wrappedValue = doubleValue
            },
        ]
        if let step {
            result.append(.step(step))
        }
        if !isEnabled {
            result.append(.disabled)
            result.append(.aria("disabled", "true"))
        }
        result.append(contentsOf: attributes)
        return result
    }
}
