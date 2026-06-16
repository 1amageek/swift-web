public struct StyleSystemOverrideStep {
    private let applyOverride: (inout StyleSystem.Override) -> Void

    public init(_ applyOverride: @escaping (inout StyleSystem.Override) -> Void) {
        self.applyOverride = applyOverride
    }

    public func apply(to override: inout StyleSystem.Override) {
        applyOverride(&override)
    }

    public func appending(_ step: StyleSystemOverrideStep) -> StyleSystemOverrideStep {
        StyleSystemOverrideStep { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemBuilder {
    public static func buildBlock(_ components: StyleSystemOverrideStep...) -> [StyleSystemOverrideStep] {
        components
    }

    public static func buildExpression(_ expression: StyleSystemOverrideStep) -> StyleSystemOverrideStep {
        expression
    }

    public static func buildOptional(_ component: [StyleSystemOverrideStep]?) -> [StyleSystemOverrideStep] {
        component ?? []
    }

    public static func buildEither(first component: [StyleSystemOverrideStep]) -> [StyleSystemOverrideStep] {
        component
    }

    public static func buildEither(second component: [StyleSystemOverrideStep]) -> [StyleSystemOverrideStep] {
        component
    }

    public static func buildArray(_ components: [[StyleSystemOverrideStep]]) -> [StyleSystemOverrideStep] {
        components.flatMap { $0 }
    }
}

public extension StyleSystem {
    init(
        id: String,
        base: StyleSystem = .default,
        @StyleSystemBuilder _ content: () -> [StyleSystemOverrideStep]
    ) {
        var override = Override(id: id)
        for step in content() {
            step.apply(to: &override)
        }
        self = base.overriding(override)
    }

    static func custom(
        id: String,
        base: StyleSystem = .default,
        @StyleSystemBuilder _ content: () -> [StyleSystemOverrideStep]
    ) -> StyleSystem {
        StyleSystem(id: id, base: base, content)
    }
}

public extension StyleSystemOverrideStep {
    func root(@StyleSystemRootBuilder _ content: () -> [StyleSystemRootOverrideStep]) -> Self {
        appending(Self.root(content))
    }

    static func root(@StyleSystemRootBuilder _ content: () -> [StyleSystemRootOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var root = override.root ?? StyleSystem.Root.Override()
            for step in steps {
                step.apply(to: &root)
            }
            override.root = root
        }
    }

    func layout(@StyleSystemLayoutBuilder _ content: () -> [StyleSystemLayoutOverrideStep]) -> Self {
        appending(Self.layout(content))
    }

    static func layout(@StyleSystemLayoutBuilder _ content: () -> [StyleSystemLayoutOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var layout = override.layout ?? StyleSystem.Layout.Override()
            for step in steps {
                step.apply(to: &layout)
            }
            override.layout = layout
        }
    }

    func surface(@StyleSystemSurfaceBuilder _ content: () -> [StyleSystemSurfaceOverrideStep]) -> Self {
        appending(Self.surface(content))
    }

    static func surface(@StyleSystemSurfaceBuilder _ content: () -> [StyleSystemSurfaceOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var surface = override.surface ?? StyleSystem.Surface.Override()
            for step in steps {
                step.apply(to: &surface)
            }
            override.surface = surface
        }
    }

    func typography(@StyleSystemTypographyBuilder _ content: () -> [StyleSystemTypographyOverrideStep]) -> Self {
        appending(Self.typography(content))
    }

    static func typography(@StyleSystemTypographyBuilder _ content: () -> [StyleSystemTypographyOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var typography = override.typography ?? StyleSystem.Typography.Override()
            for step in steps {
                step.apply(to: &typography)
            }
            override.typography = typography
        }
    }

    func control(@StyleSystemControlBuilder _ content: () -> [StyleSystemControlOverrideStep]) -> Self {
        appending(Self.control(content))
    }

    static func control(@StyleSystemControlBuilder _ content: () -> [StyleSystemControlOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var control = override.control ?? StyleSystem.Control.Override()
            for step in steps {
                step.apply(to: &control)
            }
            override.control = control
        }
    }

    func button(@StyleSystemButtonBuilder _ content: () -> [StyleSystemButtonOverrideStep]) -> Self {
        appending(Self.button(content))
    }

    static func button(@StyleSystemButtonBuilder _ content: () -> [StyleSystemButtonOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var button = override.button ?? StyleSystem.Button.Override()
            for step in steps {
                step.apply(to: &button)
            }
            override.button = button
        }
    }

    func field(@StyleSystemFieldBuilder _ content: () -> [StyleSystemFieldOverrideStep]) -> Self {
        appending(Self.field(content))
    }

    static func field(@StyleSystemFieldBuilder _ content: () -> [StyleSystemFieldOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var field = override.field ?? StyleSystem.Field.Override()
            for step in steps {
                step.apply(to: &field)
            }
            override.field = field
        }
    }

    func badge(@StyleSystemBadgeBuilder _ content: () -> [StyleSystemBadgeOverrideStep]) -> Self {
        appending(Self.badge(content))
    }

    static func badge(@StyleSystemBadgeBuilder _ content: () -> [StyleSystemBadgeOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var badge = override.badge ?? StyleSystem.Badge.Override()
            for step in steps {
                step.apply(to: &badge)
            }
            override.badge = badge
        }
    }

    func valueDisplay(@StyleSystemValueDisplayBuilder _ content: () -> [StyleSystemValueDisplayOverrideStep]) -> Self {
        appending(Self.valueDisplay(content))
    }

    static func valueDisplay(@StyleSystemValueDisplayBuilder _ content: () -> [StyleSystemValueDisplayOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var valueDisplay = override.valueDisplay ?? StyleSystem.ValueDisplay.Override()
            for step in steps {
                step.apply(to: &valueDisplay)
            }
            override.valueDisplay = valueDisplay
        }
    }

    func navigation(@StyleSystemNavigationBuilder _ content: () -> [StyleSystemNavigationOverrideStep]) -> Self {
        appending(Self.navigation(content))
    }

    static func navigation(@StyleSystemNavigationBuilder _ content: () -> [StyleSystemNavigationOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var navigation = override.navigation ?? StyleSystem.Navigation.Override()
            for step in steps {
                step.apply(to: &navigation)
            }
            override.navigation = navigation
        }
    }

    func toggle(@StyleSystemToggleBuilder _ content: () -> [StyleSystemToggleOverrideStep]) -> Self {
        appending(Self.toggle(content))
    }

    static func toggle(@StyleSystemToggleBuilder _ content: () -> [StyleSystemToggleOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var toggle = override.toggle ?? StyleSystem.Toggle.Override()
            for step in steps {
                step.apply(to: &toggle)
            }
            override.toggle = toggle
        }
    }

    func motion(@StyleSystemMotionBuilder _ content: () -> [StyleSystemMotionOverrideStep]) -> Self {
        appending(Self.motion(content))
    }

    static func motion(@StyleSystemMotionBuilder _ content: () -> [StyleSystemMotionOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var motion = override.motion ?? StyleSystem.Motion.Override()
            for step in steps {
                step.apply(to: &motion)
            }
            override.motion = motion
        }
    }

    func material(@StyleSystemMaterialBuilder _ content: () -> [StyleSystemMaterialOverrideStep]) -> Self {
        appending(Self.material(content))
    }

    static func material(@StyleSystemMaterialBuilder _ content: () -> [StyleSystemMaterialOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var material = override.material ?? StyleSystem.Material.Override()
            for step in steps {
                step.apply(to: &material)
            }
            override.material = material
        }
    }
}
