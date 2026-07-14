import SwiftWebUITheme
import SwiftHTML
import Synchronization

/// Tracks whether a drag is in progress so `onEditingChanged` fires exactly
/// once per transition: `true` on the first `input` of a drag and `false` on
/// the native `change` event that a range input emits on release.
private final class SliderEditingRuntimeState: Sendable {
    private let isEditing = Mutex(false)

    /// Returns `true` only on the idle-to-editing transition.
    func beginEditing() -> Bool {
        isEditing.withLock { isEditing in
            guard !isEditing else {
                return false
            }
            isEditing = true
            return true
        }
    }

    /// Returns `true` only when an editing session was active.
    func endEditing() -> Bool {
        isEditing.withLock { isEditing in
            guard isEditing else {
                return false
            }
            isEditing = false
            return true
        }
    }
}

public struct Slider: AttributeComponent {
    private let value: Binding<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: @Sendable (Bool) -> Void
    private let attributes: [HTMLAttribute]
    private let runtimeState = SliderEditingRuntimeState()
    @Environment({ $0.controlSize }) private var controlSize: ControlSize
    @Environment({ $0.isEnabled }) private var isEnabled: Bool
    @Environment({ $0.tint }) private var tint: Color?

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
        var style = controlTintStyle(tint?.cssValue)
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
        let onEditingChanged = self.onEditingChanged
        let runtimeState = self.runtimeState
        var result: [HTMLAttribute] = [
            .type(.range),
            .value(value.wrappedValue),
            .min(bounds.lowerBound),
            .max(bounds.upperBound),
            // `input` fires continuously while the thumb moves, so only the
            // first event of a drag reports the editing start. The native
            // `change` event fires once when the user releases the thumb (a
            // trusted end-of-interaction signal on range inputs) and reports
            // the editing end.
            .onInput { event in
                guard let rawValue = event.value,
                      let doubleValue = Double(rawValue)
                else {
                    return
                }
                if runtimeState.beginEditing() {
                    onEditingChanged(true)
                }
                value.wrappedValue = doubleValue
            },
            .onChange { _ in
                if runtimeState.endEditing() {
                    onEditingChanged(false)
                }
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
