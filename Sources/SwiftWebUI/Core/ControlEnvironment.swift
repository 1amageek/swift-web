import SwiftHTML

private struct IsEnabledEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = true
}

private struct ControlSizeEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ControlSize.regular
}

private struct ControlStateEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ControlState.enabled
}

private struct TintEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = "var(--swui-accent)"
}

private struct ButtonStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ButtonStyleKind.automatic
}

private struct IsInsideFormEnvironmentKey: ClientEnvironmentKey {
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

    var isInsideForm: Bool {
        get { self[IsInsideFormEnvironmentKey.self] }
        set { self[IsInsideFormEnvironmentKey.self] = newValue }
    }
}
