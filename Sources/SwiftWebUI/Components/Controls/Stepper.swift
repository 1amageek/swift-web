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
        class:
          "swui-stepper \(controlSize.className) \(MaterialClass.material) \(MaterialClass.thin)",
        extra: attributes
      )
    ) {
      span(.class("swui-stepper-text")) {
        span(.class("swui-stepper-label")) {
          title
        }
        span(.class("swui-stepper-value"), .aria("live", "polite")) {
          String(value.wrappedValue)
        }
      }
      span(.class("swui-stepper-actions"), .role("group"), .aria("label", "\(title) controls")) {
        stepperButton(
          symbol: "−",
          label: "Decrement \(title)",
          isEnabled: canDecrement
        ) {
          value.wrappedValue = Self.clamped(value.wrappedValue - step, bounds: bounds)
        }
        stepperButton(
          symbol: "+",
          label: "Increment \(title)",
          isEnabled: canIncrement
        ) {
          value.wrappedValue = Self.clamped(value.wrappedValue + step, bounds: bounds)
        }
      }
    }
  }

  public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
    Self(
      title: title, value: value, step: step, bounds: bounds,
      attributes: self.attributes + attributes)
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

  private func stepperButton(
    symbol: String,
    label: String,
    isEnabled: Bool,
    action: @escaping () -> Void
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
