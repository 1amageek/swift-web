import SwiftWebUITheme
import SwiftHTML

/// A control that increments or decrements a value.
///
/// The stepper renders its title and the two buttons; it does not display the
/// current value. Interpolate the value into the title to show it.
public struct Stepper: WebUIAttributeComponent {
    private let title: String
    private let value: Binding<Int>?
    private let step: Int
    private let bounds: ClosedRange<Int>?
    private let onIncrement: (@Sendable () -> Void)?
    private let onDecrement: (@Sendable () -> Void)?
    private let onEditingChanged: @Sendable (Bool) -> Void
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize: ControlSize
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.tint) private var tint: Color?

    public init(
        _ title: String,
        value: Binding<Int>,
        in bounds: ClosedRange<Int>,
        step: Int = 1,
        onEditingChanged: @escaping @Sendable (Bool) -> Void = { _ in },
        _ attributes: HTMLAttribute...
    ) {
        self.init(
            title: title,
            value: value,
            step: step,
            bounds: bounds,
            onIncrement: nil,
            onDecrement: nil,
            onEditingChanged: onEditingChanged,
            attributes: attributes
        )
    }

    public init(
        _ title: String,
        value: Binding<Int>,
        step: Int = 1,
        onEditingChanged: @escaping @Sendable (Bool) -> Void = { _ in },
        _ attributes: HTMLAttribute...
    ) {
        self.init(
            title: title,
            value: value,
            step: step,
            bounds: nil,
            onIncrement: nil,
            onDecrement: nil,
            onEditingChanged: onEditingChanged,
            attributes: attributes
        )
    }

    @available(*, deprecated, message: "Use init(_:value:in:step:onEditingChanged:) — the canonical argument order puts the bounds before the step.")
    public init(
        _ title: String,
        value: Binding<Int>,
        step: Int,
        in bounds: ClosedRange<Int>?,
        onEditingChanged: @escaping @Sendable (Bool) -> Void = { _ in },
        _ attributes: HTMLAttribute...
    ) {
        self.init(
            title: title,
            value: value,
            step: step,
            bounds: bounds,
            onIncrement: nil,
            onDecrement: nil,
            onEditingChanged: onEditingChanged,
            attributes: attributes
        )
    }

    public init(
        _ title: String,
        onIncrement: (@Sendable () -> Void)?,
        onDecrement: (@Sendable () -> Void)?,
        onEditingChanged: @escaping @Sendable (Bool) -> Void = { _ in },
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.value = nil
        self.step = 1
        self.bounds = nil
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onEditingChanged = onEditingChanged
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let value = self.value
        let step = self.step
        let bounds = self.bounds
        let onIncrement = self.onIncrement
        let onDecrement = self.onDecrement
        let onEditingChanged = self.onEditingChanged

        Element(
            "div",
            attributes: mergedAttributes(
                class: containerClassName,
                styles: controlTintStyle(tint?.cssValue),
                extra: [.role("group"), .aria("label", title)] + attributes
            )
        ) {
            span(.class("swui-stepper-label")) {
                title
            }
            stepperButton(
                symbol: "−",
                label: "Decrement \(title)",
                isEnabled: canDecrement
            ) {
                onEditingChanged(true)
                if let value {
                    value.wrappedValue = Self.clamped(value.wrappedValue - step, bounds: bounds)
                } else {
                    onDecrement?()
                }
                onEditingChanged(false)
            }
            stepperButton(
                symbol: "+",
                label: "Increment \(title)",
                isEnabled: canIncrement
            ) {
                onEditingChanged(true)
                if let value {
                    value.wrappedValue = Self.clamped(value.wrappedValue + step, bounds: bounds)
                } else {
                    onIncrement?()
                }
                onEditingChanged(false)
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            title: title,
            value: value,
            step: step,
            bounds: bounds,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            onEditingChanged: onEditingChanged,
            attributes: self.attributes + attributes
        )
    }

    private init(
        title: String,
        value: Binding<Int>?,
        step: Int,
        bounds: ClosedRange<Int>?,
        onIncrement: (@Sendable () -> Void)?,
        onDecrement: (@Sendable () -> Void)?,
        onEditingChanged: @escaping @Sendable (Bool) -> Void,
        attributes: [HTMLAttribute]
    ) {
        self.title = title
        self.value = value
        self.step = step
        self.bounds = bounds
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onEditingChanged = onEditingChanged
        self.attributes = attributes
    }

    private var containerClassName: String {
        [
            "swui-stepper",
            controlSize.className,
            isEnabled ? "swui-control-enabled" : "swui-control-disabled",
        ].joined(separator: " ")
    }

    private var canDecrement: Bool {
        guard isEnabled else {
            return false
        }
        guard let value else {
            return onDecrement != nil
        }
        guard let bounds else {
            return true
        }
        return value.wrappedValue > bounds.lowerBound
    }

    private var canIncrement: Bool {
        guard isEnabled else {
            return false
        }
        guard let value else {
            return onIncrement != nil
        }
        guard let bounds else {
            return true
        }
        return value.wrappedValue < bounds.upperBound
    }

    private func stepperButton(
        symbol: String,
        label: String,
        isEnabled: Bool,
        action: @escaping @Sendable () -> Void
    ) -> Element {
        Element(
            "button",
            attributes: [
                .type(ButtonType.button),
                .class("swui-stepper-button"),
                .aria("label", label),
                .onClick(action),
            ] + (isEnabled ? [] : [.disabled, .aria("disabled", "true")])
        ) {
            span(.aria("hidden", "true")) {
                symbol
            }
        }
    }

    private static func clamped(_ proposedValue: Int, bounds: ClosedRange<Int>?) -> Int {
        guard let bounds else {
            return proposedValue
        }
        return min(max(proposedValue, bounds.lowerBound), bounds.upperBound)
    }
}
