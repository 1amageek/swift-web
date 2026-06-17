import SwiftHTML

struct IsEnabledEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = true
}

struct ControlSizeEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ControlSize.regular
}

struct ControlStateEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ControlState.enabled
}

struct TintEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = "var(--swui-accent)"
}

struct ButtonStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ButtonStyleKind.automatic
}

struct PickerStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = PickerStyleKind.automatic
}

struct IsInsideFormEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    public var isEnabled: Bool {
        get { self[IsEnabledEnvironmentKey.self] }
        set { self[IsEnabledEnvironmentKey.self] = newValue }
    }

    public var controlSize: ControlSize {
        get { self[ControlSizeEnvironmentKey.self] }
        set { self[ControlSizeEnvironmentKey.self] = newValue }
    }

    public var controlState: ControlState {
        get { self[ControlStateEnvironmentKey.self] }
        set { self[ControlStateEnvironmentKey.self] = newValue }
    }

    public var tint: String {
        get { self[TintEnvironmentKey.self] }
        set { self[TintEnvironmentKey.self] = newValue }
    }

    public var buttonStyle: ButtonStyleKind {
        get { self[ButtonStyleEnvironmentKey.self] }
        set { self[ButtonStyleEnvironmentKey.self] = newValue }
    }

    public var pickerStyle: PickerStyleKind {
        get { self[PickerStyleEnvironmentKey.self] }
        set { self[PickerStyleEnvironmentKey.self] = newValue }
    }

    var isInsideForm: Bool {
        get { self[IsInsideFormEnvironmentKey.self] }
        set { self[IsInsideFormEnvironmentKey.self] = newValue }
    }
}
