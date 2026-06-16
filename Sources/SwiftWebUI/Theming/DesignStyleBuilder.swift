public struct DesignStyleOverrideStep {
    private let applyOverride: (inout DesignStyle.Override) -> Void

    public init(_ applyOverride: @escaping (inout DesignStyle.Override) -> Void) {
        self.applyOverride = applyOverride
    }

    public func apply(to override: inout DesignStyle.Override) {
        applyOverride(&override)
    }

    public func appending(_ step: DesignStyleOverrideStep) -> DesignStyleOverrideStep {
        DesignStyleOverrideStep { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum DesignStyleBuilder {
    public static func buildBlock(_ components: DesignStyleOverrideStep...) -> [DesignStyleOverrideStep] {
        components
    }

    public static func buildExpression(_ expression: DesignStyleOverrideStep) -> DesignStyleOverrideStep {
        expression
    }

    public static func buildOptional(_ component: [DesignStyleOverrideStep]?) -> [DesignStyleOverrideStep] {
        component ?? []
    }

    public static func buildEither(first component: [DesignStyleOverrideStep]) -> [DesignStyleOverrideStep] {
        component
    }

    public static func buildEither(second component: [DesignStyleOverrideStep]) -> [DesignStyleOverrideStep] {
        component
    }

    public static func buildArray(_ components: [[DesignStyleOverrideStep]]) -> [DesignStyleOverrideStep] {
        components.flatMap { $0 }
    }
}

public extension DesignStyle {
    init(
        id: String,
        base: DesignStyle = .default,
        @DesignStyleBuilder _ content: () -> [DesignStyleOverrideStep]
    ) {
        var override = Override(id: id)
        for step in content() {
            step.apply(to: &override)
        }
        self = base.overriding(override)
    }

    static func custom(
        id: String,
        base: DesignStyle = .default,
        @DesignStyleBuilder _ content: () -> [DesignStyleOverrideStep]
    ) -> DesignStyle {
        DesignStyle(id: id, base: base, content)
    }
}

public extension DesignStyleOverrideStep {
    func root(@DesignStyleRootBuilder _ content: () -> [DesignStyleRootOverrideStep]) -> Self {
        appending(Self.root(content))
    }

    static func root(@DesignStyleRootBuilder _ content: () -> [DesignStyleRootOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var root = override.root ?? DesignStyle.Root.Override()
            for step in steps {
                step.apply(to: &root)
            }
            override.root = root
        }
    }

    func layout(@DesignStyleLayoutBuilder _ content: () -> [DesignStyleLayoutOverrideStep]) -> Self {
        appending(Self.layout(content))
    }

    static func layout(@DesignStyleLayoutBuilder _ content: () -> [DesignStyleLayoutOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var layout = override.layout ?? DesignStyle.Layout.Override()
            for step in steps {
                step.apply(to: &layout)
            }
            override.layout = layout
        }
    }

    func surface(@DesignStyleSurfaceBuilder _ content: () -> [DesignStyleSurfaceOverrideStep]) -> Self {
        appending(Self.surface(content))
    }

    static func surface(@DesignStyleSurfaceBuilder _ content: () -> [DesignStyleSurfaceOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var surface = override.surface ?? DesignStyle.Surface.Override()
            for step in steps {
                step.apply(to: &surface)
            }
            override.surface = surface
        }
    }

    func typography(@DesignStyleTypographyBuilder _ content: () -> [DesignStyleTypographyOverrideStep]) -> Self {
        appending(Self.typography(content))
    }

    static func typography(@DesignStyleTypographyBuilder _ content: () -> [DesignStyleTypographyOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var typography = override.typography ?? DesignStyle.Typography.Override()
            for step in steps {
                step.apply(to: &typography)
            }
            override.typography = typography
        }
    }

    func control(@DesignStyleControlBuilder _ content: () -> [DesignStyleControlOverrideStep]) -> Self {
        appending(Self.control(content))
    }

    static func control(@DesignStyleControlBuilder _ content: () -> [DesignStyleControlOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var control = override.control ?? DesignStyle.Control.Override()
            for step in steps {
                step.apply(to: &control)
            }
            override.control = control
        }
    }

    func button(@DesignStyleButtonBuilder _ content: () -> [DesignStyleButtonOverrideStep]) -> Self {
        appending(Self.button(content))
    }

    static func button(@DesignStyleButtonBuilder _ content: () -> [DesignStyleButtonOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var button = override.button ?? DesignStyle.Button.Override()
            for step in steps {
                step.apply(to: &button)
            }
            override.button = button
        }
    }

    func field(@DesignStyleFieldBuilder _ content: () -> [DesignStyleFieldOverrideStep]) -> Self {
        appending(Self.field(content))
    }

    static func field(@DesignStyleFieldBuilder _ content: () -> [DesignStyleFieldOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var field = override.field ?? DesignStyle.Field.Override()
            for step in steps {
                step.apply(to: &field)
            }
            override.field = field
        }
    }

    func badge(@DesignStyleBadgeBuilder _ content: () -> [DesignStyleBadgeOverrideStep]) -> Self {
        appending(Self.badge(content))
    }

    static func badge(@DesignStyleBadgeBuilder _ content: () -> [DesignStyleBadgeOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var badge = override.badge ?? DesignStyle.Badge.Override()
            for step in steps {
                step.apply(to: &badge)
            }
            override.badge = badge
        }
    }

    func valueDisplay(@DesignStyleValueDisplayBuilder _ content: () -> [DesignStyleValueDisplayOverrideStep]) -> Self {
        appending(Self.valueDisplay(content))
    }

    static func valueDisplay(@DesignStyleValueDisplayBuilder _ content: () -> [DesignStyleValueDisplayOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var valueDisplay = override.valueDisplay ?? DesignStyle.ValueDisplay.Override()
            for step in steps {
                step.apply(to: &valueDisplay)
            }
            override.valueDisplay = valueDisplay
        }
    }

    func navigation(@DesignStyleNavigationBuilder _ content: () -> [DesignStyleNavigationOverrideStep]) -> Self {
        appending(Self.navigation(content))
    }

    static func navigation(@DesignStyleNavigationBuilder _ content: () -> [DesignStyleNavigationOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var navigation = override.navigation ?? DesignStyle.Navigation.Override()
            for step in steps {
                step.apply(to: &navigation)
            }
            override.navigation = navigation
        }
    }

    func toggle(@DesignStyleToggleBuilder _ content: () -> [DesignStyleToggleOverrideStep]) -> Self {
        appending(Self.toggle(content))
    }

    static func toggle(@DesignStyleToggleBuilder _ content: () -> [DesignStyleToggleOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var toggle = override.toggle ?? DesignStyle.Toggle.Override()
            for step in steps {
                step.apply(to: &toggle)
            }
            override.toggle = toggle
        }
    }

    func motion(@DesignStyleMotionBuilder _ content: () -> [DesignStyleMotionOverrideStep]) -> Self {
        appending(Self.motion(content))
    }

    static func motion(@DesignStyleMotionBuilder _ content: () -> [DesignStyleMotionOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var motion = override.motion ?? DesignStyle.Motion.Override()
            for step in steps {
                step.apply(to: &motion)
            }
            override.motion = motion
        }
    }

    func material(@DesignStyleMaterialBuilder _ content: () -> [DesignStyleMaterialOverrideStep]) -> Self {
        appending(Self.material(content))
    }

    static func material(@DesignStyleMaterialBuilder _ content: () -> [DesignStyleMaterialOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var material = override.material ?? DesignStyle.Material.Override()
            for step in steps {
                step.apply(to: &material)
            }
            override.material = material
        }
    }
}
