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
    // Absent until a `.tint(...)` is applied. Keeping the default `nil` lets each
    // control's CSS fall back to its style-system token
    // (`var(--swui-control-tint, var(--swui-button-primary-background))`, etc.)
    // instead of an environment default silently overriding those tokens.
    static let defaultValue: String? = nil
}

struct ButtonStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ButtonStyleKind.automatic
}

struct PickerStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = PickerStyleKind.automatic
}

struct ToggleStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ToggleStyleKind.automatic
}

struct TextFieldStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = TextFieldStyleKind.automatic
}

struct LabelStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = LabelStyleKind.automatic
}

struct ListStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ListStyleKind.automatic
}

struct FormStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = FormStyleKind.automatic
}

struct MenuStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = MenuStyleKind.automatic
}

struct ProgressViewStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = ProgressViewStyleKind.automatic
}

struct GaugeStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = GaugeStyleKind.automatic
}

struct TabViewStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = TabViewStyleKind.automatic
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

    public var tint: String? {
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

    public var toggleStyle: ToggleStyleKind {
        get { self[ToggleStyleEnvironmentKey.self] }
        set { self[ToggleStyleEnvironmentKey.self] = newValue }
    }

    public var textFieldStyle: TextFieldStyleKind {
        get { self[TextFieldStyleEnvironmentKey.self] }
        set { self[TextFieldStyleEnvironmentKey.self] = newValue }
    }

    public var labelStyle: LabelStyleKind {
        get { self[LabelStyleEnvironmentKey.self] }
        set { self[LabelStyleEnvironmentKey.self] = newValue }
    }

    public var listStyle: ListStyleKind {
        get { self[ListStyleEnvironmentKey.self] }
        set { self[ListStyleEnvironmentKey.self] = newValue }
    }

    public var formStyle: FormStyleKind {
        get { self[FormStyleEnvironmentKey.self] }
        set { self[FormStyleEnvironmentKey.self] = newValue }
    }

    public var menuStyle: MenuStyleKind {
        get { self[MenuStyleEnvironmentKey.self] }
        set { self[MenuStyleEnvironmentKey.self] = newValue }
    }

    public var progressViewStyle: ProgressViewStyleKind {
        get { self[ProgressViewStyleEnvironmentKey.self] }
        set { self[ProgressViewStyleEnvironmentKey.self] = newValue }
    }

    public var gaugeStyle: GaugeStyleKind {
        get { self[GaugeStyleEnvironmentKey.self] }
        set { self[GaugeStyleEnvironmentKey.self] = newValue }
    }

    public var tabViewStyle: TabViewStyleKind {
        get { self[TabViewStyleEnvironmentKey.self] }
        set { self[TabViewStyleEnvironmentKey.self] = newValue }
    }

    var isInsideForm: Bool {
        get { self[IsInsideFormEnvironmentKey.self] }
        set { self[IsInsideFormEnvironmentKey.self] = newValue }
    }
}
