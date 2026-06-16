import SwiftHTML

public struct Stepper: WebUIAttributeComponent {
    private let title: String
    private let value: Binding<Int>
    private let step: Int
    private let bounds: ClosedRange<Int>?
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        value: Binding<Int>,
        step: Int = 1,
        in bounds: ClosedRange<Int>? = nil,
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.value = value
        self.step = step
        self.bounds = bounds
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let value = self.value
        let step = self.step
        let bounds = self.bounds
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-stepper \(controlSize.className)",
                extra: attributes
            )
        ) {
            span(.class("swui-stepper-label")) {
                title
            }
            Button("Decrement", prominence: .secondary) {
                value.wrappedValue = Self.clamped(value.wrappedValue - step, bounds: bounds)
            }
            .disabled(!canDecrement)
            span(.class("swui-stepper-value"), .aria("live", "polite")) {
                String(value.wrappedValue)
            }
            Button("Increment", prominence: .secondary) {
                value.wrappedValue = Self.clamped(value.wrappedValue + step, bounds: bounds)
            }
            .disabled(!canIncrement)
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, value: value, step: step, bounds: bounds, attributes: self.attributes + attributes)
    }

    private init(
        title: String,
        value: Binding<Int>,
        step: Int,
        bounds: ClosedRange<Int>?,
        attributes: [HTMLAttribute]
    ) {
        self.title = title
        self.value = value
        self.step = step
        self.bounds = bounds
        self.attributes = attributes
    }

    private var canDecrement: Bool {
        guard isEnabled else {
            return false
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
        guard let bounds else {
            return true
        }
        return value.wrappedValue < bounds.upperBound
    }

    private static func clamped(_ proposedValue: Int, bounds: ClosedRange<Int>?) -> Int {
        guard let bounds else {
            return proposedValue
        }
        return min(max(proposedValue, bounds.lowerBound), bounds.upperBound)
    }
}
