import SwiftWebUITheme
import SwiftHTML

public struct SubmitTriggers: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let text = SubmitTriggers(rawValue: 1 << 0)
    public static let search = SubmitTriggers(rawValue: 1 << 1)
    public static let all: SubmitTriggers = [.text, .search]
}

@propertyWrapper
public struct FocusState<Value: Hashable & Codable & Sendable>: Sendable {
    private let state: State<Value>

    public init(wrappedValue: Value) {
        self.state = State(wrappedValue: wrappedValue)
    }

    public var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }

    public var projectedValue: Binding {
        Binding(
            get: { state.wrappedValue },
            set: { state.wrappedValue = $0 }
        )
    }

    public struct Binding: Sendable {
        private let getValue: @Sendable () -> Value
        private let setValue: @Sendable (Value) -> Void

        public init(
            get: @escaping @Sendable () -> Value,
            set: @escaping @Sendable (Value) -> Void
        ) {
            self.getValue = get
            self.setValue = set
        }

        public var wrappedValue: Value {
            get { getValue() }
            nonmutating set { setValue(newValue) }
        }
    }
}

public extension FocusState where Value == Bool {
    init() {
        self.init(wrappedValue: false)
    }
}

public extension FocusState where Value: ExpressibleByNilLiteral {
    init() {
        self.init(wrappedValue: nil)
    }
}

private enum ChangeObservationValue<Value: Codable & Sendable>: Sendable {
    case absent
    case present(Value)
}

extension ChangeObservationValue: Equatable where Value: Equatable {}
extension ChangeObservationValue: Codable where Value: Codable {}

public struct OnChangeModifier<Value: Equatable & Codable & Sendable>: ComponentModifier {
    private let value: Value
    private let initial: Bool
    private let action: @Sendable (Value, Value) -> Void
    @State private var previousValue: ChangeObservationValue<Value>

    init(
        value: Value,
        initial: Bool,
        action: @escaping @Sendable (Value, Value) -> Void
    ) {
        self.value = value
        self.initial = initial
        self.action = action
        self._previousValue = State(wrappedValue: .absent)
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let _ = observeChange()
        Element(
            "div",
            attributes: [
                .class("swui-modifier swui-attribute swui-semantic-modifier"),
                .data("change-observer", "value"),
                .data("change-initial", initial ? "true" : "false"),
            ]
        ) {
            content
        }
    }

    private func observeChange() {
        switch previousValue {
        case .absent:
            if initial {
                action(value, value)
            }
            previousValue = .present(value)
        case .present(let previous):
            guard previous != value else {
                return
            }
            action(previous, value)
            previousValue = .present(value)
        }
    }
}

public extension HTML {
    func onSubmit(
        of triggers: SubmitTriggers = .text,
        _ action: @escaping @Sendable () -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("submit-triggers", triggers.cssName),
            .onSubmit { _ in action() },
        ], role: .semantic))
    }

    func submitScope(_ isBlocking: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("submit-scope", isBlocking ? "blocking" : "nonblocking")
        ], role: .semantic))
    }

    func focused(_ condition: FocusState<Bool>.Binding) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .event("focusin") { _ in condition.wrappedValue = true },
            .event("focusout") { _ in condition.wrappedValue = false },
        ], role: .semantic))
    }

    func focused<Value>(
        _ binding: FocusState<Value?>.Binding,
        equals value: Value
    ) -> ModifiedContent<Self, HTMLAttributeModifier> where Value: Hashable & Codable & Sendable {
        modifier(HTMLAttributeModifier([
            .event("focusin") { _ in binding.wrappedValue = value },
            .event("focusout") { _ in
                if binding.wrappedValue == value {
                    binding.wrappedValue = nil
                }
            },
        ], role: .semantic))
    }

    func focusable(_ isFocusable: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            HTMLAttribute("tabindex", isFocusable ? "0" : "-1"),
            .data("focusable", isFocusable ? "true" : "false"),
        ], role: .semantic))
    }

    func onChange<Value>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping @Sendable (Value, Value) -> Void
    ) -> ModifiedContent<Self, OnChangeModifier<Value>> where Value: Equatable & Codable & Sendable {
        modifier(OnChangeModifier(value: value, initial: initial, action: action))
    }

    func onChange<Value>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping @Sendable (Value) -> Void
    ) -> ModifiedContent<Self, OnChangeModifier<Value>> where Value: Equatable & Codable & Sendable {
        onChange(of: value, initial: initial) { _, newValue in
            action(newValue)
        }
    }
}

extension SubmitTriggers {
    var cssName: String {
        if self == .all {
            return "all"
        }
        var values: [String] = []
        if contains(.text) {
            values.append("text")
        }
        if contains(.search) {
            values.append("search")
        }
        return values.joined(separator: " ")
    }
}
