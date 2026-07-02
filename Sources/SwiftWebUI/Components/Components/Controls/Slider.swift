import SwiftWebUITheme
import SwiftHTML

public struct Slider: WebUIAttributeComponent {
    private let value: Binding<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: @Sendable (Bool) -> Void
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize: ControlSize
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.tint) private var tint: String?

    public init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        onEditingChanged: @escaping @Sendable (Bool) -> Void = { _ in },
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        // A transparent native range input on top owns all interaction (drag,
        // keyboard, step, focus, accessibility); the visible track, fill, and
        // Liquid Glass thumb are drawn beneath it and positioned from
        // `--swui-slider-progress`. The client sets that variable live on input;
        // the server seeds it inline so the first paint is already correct.
        Element("span", attributes: wrapperAttributes) {
            span(.class("swui-slider-track")) {
                span(.class("swui-slider-fill")) {}
            }
            Element(
                "input",
                attributes: mergedAttributes(class: "swui-slider-input", extra: inputAttributes),
                isVoid: true
            )
            span(.class("swui-slider-thumb \(MaterialClass.glass)")) {}
        }
    }

    private var wrapperAttributes: [HTMLAttribute] {
        var style = controlTintStyle(tint)
        style.append(.custom("--swui-slider-progress", progressValue))
        return mergedAttributes(
            class: controlClassName(
                "swui-slider",
                controlSize.className,
                LayoutClass.fillHorizontal,
                isEnabled ? nil : "swui-control-disabled"
            ),
            styles: style,
            extra: []
        )
    }

    /// The fraction of the track the value fills, clamped to `0...1`. Drives the
    /// fill width and thumb offset before the client script takes over.
    private var progressValue: String {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0, span.isFinite else { return "0" }
        let ratio = (value.wrappedValue - bounds.lowerBound) / span
        return trimmedNumber(Swift.min(1, Swift.max(0, ratio)))
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            value: value,
            bounds: bounds,
            step: step,
            onEditingChanged: onEditingChanged,
            attributes: self.attributes + attributes
        )
    }

    private init(
        value: Binding<Double>,
        bounds: ClosedRange<Double>,
        step: Double?,
        onEditingChanged: @escaping @Sendable (Bool) -> Void,
        attributes: [HTMLAttribute]
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.onEditingChanged = onEditingChanged
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
                onEditingChanged(true)
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
