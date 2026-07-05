public struct ThemeOverrideStep {
    private let applyOverride: (inout Theme.Override) -> Void

    init(_ applyOverride: @escaping (inout Theme.Override) -> Void) {
        self.applyOverride = applyOverride
    }

    func apply(to override: inout Theme.Override) {
        applyOverride(&override)
    }

    public func appending(_ step: ThemeOverrideStep) -> ThemeOverrideStep {
        ThemeOverrideStep { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeBuilder {
    public static func buildBlock(_ components: ThemeOverrideStep...) -> [ThemeOverrideStep] {
        components
    }

    public static func buildExpression(_ expression: ThemeOverrideStep) -> ThemeOverrideStep {
        expression
    }

    public static func buildOptional(_ component: [ThemeOverrideStep]?) -> [ThemeOverrideStep] {
        component ?? []
    }

    public static func buildEither(first component: [ThemeOverrideStep]) -> [ThemeOverrideStep] {
        component
    }

    public static func buildEither(second component: [ThemeOverrideStep]) -> [ThemeOverrideStep] {
        component
    }

    public static func buildArray(_ components: [[ThemeOverrideStep]]) -> [ThemeOverrideStep] {
        components.flatMap { $0 }
    }
}

public extension Theme {
    init(
        id: String,
        base: Theme = .default,
        @ThemeBuilder _ content: () -> [ThemeOverrideStep]
    ) {
        var override = Override(id: id)
        for step in content() {
            step.apply(to: &override)
        }
        self = base.overriding(override)
    }

    static func custom(
        id: String,
        base: Theme = .default,
        @ThemeBuilder _ content: () -> [ThemeOverrideStep]
    ) -> Theme {
        Theme(id: id, base: base, content)
    }
}

public extension ThemeOverrideStep {
    func root(@ThemeRootBuilder _ content: () -> [ThemeRootOverrideStep]) -> Self {
        appending(Self.root(content))
    }

    static func root(@ThemeRootBuilder _ content: () -> [ThemeRootOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var root = override.root ?? Theme.Root.Override()
            for step in steps {
                step.apply(to: &root)
            }
            override.root = root
        }
    }

    func layout(@ThemeLayoutBuilder _ content: () -> [ThemeLayoutOverrideStep]) -> Self {
        appending(Self.layout(content))
    }

    static func layout(@ThemeLayoutBuilder _ content: () -> [ThemeLayoutOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var layout = override.layout ?? Theme.Layout.Override()
            for step in steps {
                step.apply(to: &layout)
            }
            override.layout = layout
        }
    }

    func surface(@ThemeSurfaceBuilder _ content: () -> [ThemeSurfaceOverrideStep]) -> Self {
        appending(Self.surface(content))
    }

    static func surface(@ThemeSurfaceBuilder _ content: () -> [ThemeSurfaceOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var surface = override.surface ?? Theme.Surface.Override()
            for step in steps {
                step.apply(to: &surface)
            }
            override.surface = surface
        }
    }

    func typography(@ThemeTypographyBuilder _ content: () -> [ThemeTypographyOverrideStep]) -> Self {
        appending(Self.typography(content))
    }

    static func typography(@ThemeTypographyBuilder _ content: () -> [ThemeTypographyOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var typography = override.typography ?? Theme.Typography.Override()
            for step in steps {
                step.apply(to: &typography)
            }
            override.typography = typography
        }
    }

    func control(@ThemeControlBuilder _ content: () -> [ThemeControlOverrideStep]) -> Self {
        appending(Self.control(content))
    }

    static func control(@ThemeControlBuilder _ content: () -> [ThemeControlOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var control = override.control ?? Theme.Control.Override()
            for step in steps {
                step.apply(to: &control)
            }
            override.control = control
        }
    }

    func button(@ThemeButtonBuilder _ content: () -> [ThemeButtonOverrideStep]) -> Self {
        appending(Self.button(content))
    }

    static func button(@ThemeButtonBuilder _ content: () -> [ThemeButtonOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var button = override.button ?? Theme.Button.Override()
            for step in steps {
                step.apply(to: &button)
            }
            override.button = button
        }
    }

    func field(@ThemeFieldBuilder _ content: () -> [ThemeFieldOverrideStep]) -> Self {
        appending(Self.field(content))
    }

    static func field(@ThemeFieldBuilder _ content: () -> [ThemeFieldOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var field = override.field ?? Theme.Field.Override()
            for step in steps {
                step.apply(to: &field)
            }
            override.field = field
        }
    }

    func badge(@ThemeBadgeBuilder _ content: () -> [ThemeBadgeOverrideStep]) -> Self {
        appending(Self.badge(content))
    }

    static func badge(@ThemeBadgeBuilder _ content: () -> [ThemeBadgeOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var badge = override.badge ?? Theme.Badge.Override()
            for step in steps {
                step.apply(to: &badge)
            }
            override.badge = badge
        }
    }

    func navigation(@ThemeNavigationBuilder _ content: () -> [ThemeNavigationOverrideStep]) -> Self {
        appending(Self.navigation(content))
    }

    static func navigation(@ThemeNavigationBuilder _ content: () -> [ThemeNavigationOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var navigation = override.navigation ?? Theme.Navigation.Override()
            for step in steps {
                step.apply(to: &navigation)
            }
            override.navigation = navigation
        }
    }

    func toggle(@ThemeToggleBuilder _ content: () -> [ThemeToggleOverrideStep]) -> Self {
        appending(Self.toggle(content))
    }

    static func toggle(@ThemeToggleBuilder _ content: () -> [ThemeToggleOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var toggle = override.toggle ?? Theme.Toggle.Override()
            for step in steps {
                step.apply(to: &toggle)
            }
            override.toggle = toggle
        }
    }

    func motion(@ThemeMotionBuilder _ content: () -> [ThemeMotionOverrideStep]) -> Self {
        appending(Self.motion(content))
    }

    static func motion(@ThemeMotionBuilder _ content: () -> [ThemeMotionOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var motion = override.motion ?? Theme.Motion.Override()
            for step in steps {
                step.apply(to: &motion)
            }
            override.motion = motion
        }
    }

    func material(@ThemeMaterialBuilder _ content: () -> [ThemeMaterialOverrideStep]) -> Self {
        appending(Self.material(content))
    }

    static func material(@ThemeMaterialBuilder _ content: () -> [ThemeMaterialOverrideStep]) -> Self {
        let steps = content()
        return Self { override in
            var material = override.material ?? Theme.Material.Override()
            for step in steps {
                step.apply(to: &material)
            }
            override.material = material
        }
    }
}
