public struct ThemeRootOverrideStep {
    private let applyOverride: (inout Theme.Root.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Root.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Root.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeRootBuilder {
    public static func buildBlock(_ components: ThemeRootOverrideStep...) -> [ThemeRootOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeRootOverrideStep) -> ThemeRootOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeRootOverrideStep]?) -> [ThemeRootOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeRootOverrideStep]) -> [ThemeRootOverrideStep] { component }
    public static func buildEither(second component: [ThemeRootOverrideStep]) -> [ThemeRootOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeRootOverrideStep]]) -> [ThemeRootOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeRootOverrideStep {
    static func pageInlinePadding(_ value: Length) -> Self { Self { $0.pageInlinePadding = value.cssValue } }
    static func stackSpacing(_ value: Space) -> Self { Self { $0.stackSpacing = value.rawValue } }
    static func stackSpacing(_ value: Length) -> Self { Self { $0.stackSpacing = value.cssValue } }
    func pageInlinePadding(_ value: Length) -> Self { appending(Self.pageInlinePadding(value)) }
    func stackSpacing(_ value: Space) -> Self { appending(Self.stackSpacing(value)) }
    func stackSpacing(_ value: Length) -> Self { appending(Self.stackSpacing(value)) }
}

public struct ThemeLayoutOverrideStep {
    private let applyOverride: (inout Theme.Layout.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Layout.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Layout.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeLayoutBuilder {
    public static func buildBlock(_ components: ThemeLayoutOverrideStep...) -> [ThemeLayoutOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeLayoutOverrideStep) -> ThemeLayoutOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeLayoutOverrideStep]?) -> [ThemeLayoutOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeLayoutOverrideStep]) -> [ThemeLayoutOverrideStep] { component }
    public static func buildEither(second component: [ThemeLayoutOverrideStep]) -> [ThemeLayoutOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeLayoutOverrideStep]]) -> [ThemeLayoutOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeLayoutOverrideStep {
    static func lazyIntrinsicSize(_ value: ThemeIntrinsicSize) -> Self { Self { $0.lazyIntrinsicSize = value.cssValue } }
    func lazyIntrinsicSize(_ value: ThemeIntrinsicSize) -> Self { appending(Self.lazyIntrinsicSize(value)) }
}

public struct ThemeSurfaceOverrideStep {
    private let applyOverride: (inout Theme.Surface.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Surface.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Surface.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeSurfaceBuilder {
    public static func buildBlock(_ components: ThemeSurfaceOverrideStep...) -> [ThemeSurfaceOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeSurfaceOverrideStep) -> ThemeSurfaceOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeSurfaceOverrideStep]?) -> [ThemeSurfaceOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeSurfaceOverrideStep]) -> [ThemeSurfaceOverrideStep] { component }
    public static func buildEither(second component: [ThemeSurfaceOverrideStep]) -> [ThemeSurfaceOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeSurfaceOverrideStep]]) -> [ThemeSurfaceOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeSurfaceOverrideStep {
    static func containerBorder(_ value: ThemeBorder) -> Self { Self { $0.containerBorder = value.cssValue } }
    static func containerRadius(_ value: Length) -> Self { Self { $0.containerRadius = value.cssValue } }
    static func containerShadow(_ value: ThemeShadow) -> Self { Self { $0.containerShadow = value.cssValue } }
    func containerBorder(_ value: ThemeBorder) -> Self { appending(Self.containerBorder(value)) }
    func containerRadius(_ value: Length) -> Self { appending(Self.containerRadius(value)) }
    func containerShadow(_ value: ThemeShadow) -> Self { appending(Self.containerShadow(value)) }
}

public struct ThemeTypographyOverrideStep {
    private let applyOverride: (inout Theme.Typography.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Typography.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Typography.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeTypographyBuilder {
    public static func buildBlock(_ components: ThemeTypographyOverrideStep...) -> [ThemeTypographyOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeTypographyOverrideStep) -> ThemeTypographyOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeTypographyOverrideStep]?) -> [ThemeTypographyOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeTypographyOverrideStep]) -> [ThemeTypographyOverrideStep] { component }
    public static func buildEither(second component: [ThemeTypographyOverrideStep]) -> [ThemeTypographyOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeTypographyOverrideStep]]) -> [ThemeTypographyOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeTypographyOverrideStep {
    static func pageHeadingSize(_ value: Length) -> Self { Self { $0.pageHeadingSize = value.cssValue } }
    static func pageHeadingLineHeight(_ value: Double) -> Self { Self { $0.pageHeadingLineHeight = trimmedNumber(value) } }
    static func sectionHeadingSize(_ value: Length) -> Self { Self { $0.sectionHeadingSize = value.cssValue } }
    static func subsectionHeadingSize(_ value: Length) -> Self { Self { $0.subsectionHeadingSize = value.cssValue } }
    func pageHeadingSize(_ value: Length) -> Self { appending(Self.pageHeadingSize(value)) }
    func pageHeadingLineHeight(_ value: Double) -> Self { appending(Self.pageHeadingLineHeight(value)) }
    func sectionHeadingSize(_ value: Length) -> Self { appending(Self.sectionHeadingSize(value)) }
    func subsectionHeadingSize(_ value: Length) -> Self { appending(Self.subsectionHeadingSize(value)) }
}

public struct ThemeControlOverrideStep {
    private let applyOverride: (inout Theme.Control.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Control.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Control.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeControlBuilder {
    public static func buildBlock(_ components: ThemeControlOverrideStep...) -> [ThemeControlOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeControlOverrideStep) -> ThemeControlOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeControlOverrideStep]?) -> [ThemeControlOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeControlOverrideStep]) -> [ThemeControlOverrideStep] { component }
    public static func buildEither(second component: [ThemeControlOverrideStep]) -> [ThemeControlOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeControlOverrideStep]]) -> [ThemeControlOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeControlOverrideStep {
    static func miniHeight(_ value: Length) -> Self { Self { $0.miniHeight = value.cssValue } }
    static func smallHeight(_ value: Length) -> Self { Self { $0.smallHeight = value.cssValue } }
    static func regularHeight(_ value: Length) -> Self { Self { $0.regularHeight = value.cssValue } }
    static func largeHeight(_ value: Length) -> Self { Self { $0.largeHeight = value.cssValue } }
    static func extraLargeHeight(_ value: Length) -> Self { Self { $0.extraLargeHeight = value.cssValue } }
    static func disabledOpacity(_ value: Double) -> Self { Self { $0.disabledOpacity = trimmedNumber(value) } }
    func miniHeight(_ value: Length) -> Self { appending(Self.miniHeight(value)) }
    func smallHeight(_ value: Length) -> Self { appending(Self.smallHeight(value)) }
    func regularHeight(_ value: Length) -> Self { appending(Self.regularHeight(value)) }
    func largeHeight(_ value: Length) -> Self { appending(Self.largeHeight(value)) }
    func extraLargeHeight(_ value: Length) -> Self { appending(Self.extraLargeHeight(value)) }
    func disabledOpacity(_ value: Double) -> Self { appending(Self.disabledOpacity(value)) }
}

public struct ThemeButtonOverrideStep {
    private let applyOverride: (inout Theme.Button.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Button.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Button.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeButtonBuilder {
    public static func buildBlock(_ components: ThemeButtonOverrideStep...) -> [ThemeButtonOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeButtonOverrideStep) -> ThemeButtonOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeButtonOverrideStep]?) -> [ThemeButtonOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeButtonOverrideStep]) -> [ThemeButtonOverrideStep] { component }
    public static func buildEither(second component: [ThemeButtonOverrideStep]) -> [ThemeButtonOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeButtonOverrideStep]]) -> [ThemeButtonOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeButtonOverrideStep {
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func primaryBackground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.primaryBackground = resolvedCSSValue(value) } }
    static func primaryForeground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.primaryForeground = resolvedCSSValue(value) } }
    static func secondaryBackground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.secondaryBackground = resolvedCSSValue(value) } }
    static func secondaryForeground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.secondaryForeground = resolvedCSSValue(value) } }
    static func secondaryBorder<S: ShapeStyle>(_ value: S) -> Self { Self { $0.secondaryBorder = resolvedCSSValue(value) } }
    static func secondaryHoverBackground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.secondaryHoverBackground = resolvedCSSValue(value) } }
    static func plainForeground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.plainForeground = resolvedCSSValue(value) } }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func primaryBackground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.primaryBackground(value)) }
    func primaryForeground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.primaryForeground(value)) }
    func secondaryBackground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.secondaryBackground(value)) }
    func secondaryForeground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.secondaryForeground(value)) }
    func secondaryBorder<S: ShapeStyle>(_ value: S) -> Self { appending(Self.secondaryBorder(value)) }
    func secondaryHoverBackground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.secondaryHoverBackground(value)) }
    func plainForeground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.plainForeground(value)) }
}

public struct ThemeFieldOverrideStep {
    private let applyOverride: (inout Theme.Field.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Field.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Field.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeFieldBuilder {
    public static func buildBlock(_ components: ThemeFieldOverrideStep...) -> [ThemeFieldOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeFieldOverrideStep) -> ThemeFieldOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeFieldOverrideStep]?) -> [ThemeFieldOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeFieldOverrideStep]) -> [ThemeFieldOverrideStep] { component }
    public static func buildEither(second component: [ThemeFieldOverrideStep]) -> [ThemeFieldOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeFieldOverrideStep]]) -> [ThemeFieldOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeFieldOverrideStep {
    static func background<S: ShapeStyle>(_ value: S) -> Self { Self { $0.background = resolvedCSSValue(value) } }
    static func border(_ value: ThemeBorder) -> Self { Self { $0.border = value.cssValue } }
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func padding(_ value: EdgeInsets) -> Self { Self { $0.padding = value.cssValue } }
    static func padding(vertical: Length, horizontal: Length) -> Self {
        Self { $0.padding = "\(vertical.cssValue) \(horizontal.cssValue)" }
    }
    static func labelSize(_ value: Length) -> Self { Self { $0.labelSize = value.cssValue } }
    func background<S: ShapeStyle>(_ value: S) -> Self { appending(Self.background(value)) }
    func border(_ value: ThemeBorder) -> Self { appending(Self.border(value)) }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func padding(_ value: EdgeInsets) -> Self { appending(Self.padding(value)) }
    func padding(vertical: Length, horizontal: Length) -> Self { appending(Self.padding(vertical: vertical, horizontal: horizontal)) }
    func labelSize(_ value: Length) -> Self { appending(Self.labelSize(value)) }
}

public struct ThemeBadgeOverrideStep {
    private let applyOverride: (inout Theme.Badge.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Badge.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Badge.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeBadgeBuilder {
    public static func buildBlock(_ components: ThemeBadgeOverrideStep...) -> [ThemeBadgeOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeBadgeOverrideStep) -> ThemeBadgeOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeBadgeOverrideStep]?) -> [ThemeBadgeOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeBadgeOverrideStep]) -> [ThemeBadgeOverrideStep] { component }
    public static func buildEither(second component: [ThemeBadgeOverrideStep]) -> [ThemeBadgeOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeBadgeOverrideStep]]) -> [ThemeBadgeOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeBadgeOverrideStep {
    static func background<S: ShapeStyle>(_ value: S) -> Self { Self { $0.background = resolvedCSSValue(value) } }
    static func border(_ value: ThemeBorder) -> Self { Self { $0.border = value.cssValue } }
    static func foreground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.foreground = resolvedCSSValue(value) } }
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func padding(_ value: EdgeInsets) -> Self { Self { $0.padding = value.cssValue } }
    static func padding(vertical: Length, horizontal: Length) -> Self {
        Self { $0.padding = "\(vertical.cssValue) \(horizontal.cssValue)" }
    }
    func background<S: ShapeStyle>(_ value: S) -> Self { appending(Self.background(value)) }
    func border(_ value: ThemeBorder) -> Self { appending(Self.border(value)) }
    func foreground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.foreground(value)) }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func padding(_ value: EdgeInsets) -> Self { appending(Self.padding(value)) }
    func padding(vertical: Length, horizontal: Length) -> Self { appending(Self.padding(vertical: vertical, horizontal: horizontal)) }
}

public struct ThemeNavigationOverrideStep {
    private let applyOverride: (inout Theme.Navigation.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Navigation.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Navigation.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeNavigationBuilder {
    public static func buildBlock(_ components: ThemeNavigationOverrideStep...) -> [ThemeNavigationOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeNavigationOverrideStep) -> ThemeNavigationOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeNavigationOverrideStep]?) -> [ThemeNavigationOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeNavigationOverrideStep]) -> [ThemeNavigationOverrideStep] { component }
    public static func buildEither(second component: [ThemeNavigationOverrideStep]) -> [ThemeNavigationOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeNavigationOverrideStep]]) -> [ThemeNavigationOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeNavigationOverrideStep {
    static func gap(_ value: Space) -> Self { Self { $0.gap = value.rawValue } }
    static func gap(_ value: Length) -> Self { Self { $0.gap = value.cssValue } }
    static func linkForeground<S: ShapeStyle>(_ value: S) -> Self { Self { $0.linkForeground = resolvedCSSValue(value) } }
    static func linkDecoration(_ value: ThemeTextDecoration) -> Self { Self { $0.linkDecoration = value.cssValue } }
    static func linkHoverDecoration(_ value: ThemeTextDecoration) -> Self { Self { $0.linkHoverDecoration = value.cssValue } }
    func gap(_ value: Space) -> Self { appending(Self.gap(value)) }
    func gap(_ value: Length) -> Self { appending(Self.gap(value)) }
    func linkForeground<S: ShapeStyle>(_ value: S) -> Self { appending(Self.linkForeground(value)) }
    func linkDecoration(_ value: ThemeTextDecoration) -> Self { appending(Self.linkDecoration(value)) }
    func linkHoverDecoration(_ value: ThemeTextDecoration) -> Self { appending(Self.linkHoverDecoration(value)) }
}

public struct ThemeToggleOverrideStep {
    private let applyOverride: (inout Theme.Toggle.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Toggle.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Toggle.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeToggleBuilder {
    public static func buildBlock(_ components: ThemeToggleOverrideStep...) -> [ThemeToggleOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeToggleOverrideStep) -> ThemeToggleOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeToggleOverrideStep]?) -> [ThemeToggleOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeToggleOverrideStep]) -> [ThemeToggleOverrideStep] { component }
    public static func buildEither(second component: [ThemeToggleOverrideStep]) -> [ThemeToggleOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeToggleOverrideStep]]) -> [ThemeToggleOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeToggleOverrideStep {
    static func width(_ value: Length) -> Self { Self { $0.width = value.cssValue } }
    static func height(_ value: Length) -> Self { Self { $0.height = value.cssValue } }
    static func thumbSize(_ value: Length) -> Self { Self { $0.thumbSize = value.cssValue } }
    static func thumbOffset(_ value: Length) -> Self { Self { $0.thumbOffset = value.cssValue } }
    static func checkedThumbOffset(_ value: Length) -> Self { Self { $0.checkedThumbOffset = value.cssValue } }
    func width(_ value: Length) -> Self { appending(Self.width(value)) }
    func height(_ value: Length) -> Self { appending(Self.height(value)) }
    func thumbSize(_ value: Length) -> Self { appending(Self.thumbSize(value)) }
    func thumbOffset(_ value: Length) -> Self { appending(Self.thumbOffset(value)) }
    func checkedThumbOffset(_ value: Length) -> Self { appending(Self.checkedThumbOffset(value)) }
}

public struct ThemeMotionOverrideStep {
    private let applyOverride: (inout Theme.Motion.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Motion.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Motion.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeMotionBuilder {
    public static func buildBlock(_ components: ThemeMotionOverrideStep...) -> [ThemeMotionOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeMotionOverrideStep) -> ThemeMotionOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeMotionOverrideStep]?) -> [ThemeMotionOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeMotionOverrideStep]) -> [ThemeMotionOverrideStep] { component }
    public static func buildEither(second component: [ThemeMotionOverrideStep]) -> [ThemeMotionOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeMotionOverrideStep]]) -> [ThemeMotionOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeMotionOverrideStep {
    static func quick(_ value: ThemeMotionTiming) -> Self { Self { $0.quick = value.cssValue } }
    static func standard(_ value: ThemeMotionTiming) -> Self { Self { $0.standard = value.cssValue } }
    func quick(_ value: ThemeMotionTiming) -> Self { appending(Self.quick(value)) }
    func standard(_ value: ThemeMotionTiming) -> Self { appending(Self.standard(value)) }
}

public struct ThemeMaterialOverrideStep {
    private let applyOverride: (inout Theme.Material.Override) -> Void
    init(_ applyOverride: @escaping (inout Theme.Material.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout Theme.Material.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum ThemeMaterialBuilder {
    public static func buildBlock(_ components: ThemeMaterialOverrideStep...) -> [ThemeMaterialOverrideStep] { components }
    public static func buildExpression(_ expression: ThemeMaterialOverrideStep) -> ThemeMaterialOverrideStep { expression }
    public static func buildOptional(_ component: [ThemeMaterialOverrideStep]?) -> [ThemeMaterialOverrideStep] { component ?? [] }
    public static func buildEither(first component: [ThemeMaterialOverrideStep]) -> [ThemeMaterialOverrideStep] { component }
    public static func buildEither(second component: [ThemeMaterialOverrideStep]) -> [ThemeMaterialOverrideStep] { component }
    public static func buildArray(_ components: [[ThemeMaterialOverrideStep]]) -> [ThemeMaterialOverrideStep] { components.flatMap { $0 } }
}

public extension ThemeMaterialOverrideStep {
    static func tint<S: ShapeStyle>(_ value: S) -> Self { Self { $0.tint = resolvedCSSValue(value) } }
    static func opacity(_ value: Double) -> Self { Self { $0.opacity = trimmedNumber(value) } }
    static func opacityStep(_ value: Double) -> Self { Self { $0.opacityStep = trimmedNumber(value) } }
    static func blur(_ value: Length) -> Self { Self { $0.blur = value.cssValue } }
    static func saturate(_ value: Double) -> Self { Self { $0.saturate = trimmedNumber(value) } }
    static func brightness(_ value: Double) -> Self { Self { $0.brightness = trimmedNumber(value) } }
    static func rim(_ value: ThemeShadow) -> Self { Self { $0.rim = value.cssValue } }
    static func refraction(_ value: ThemeRefraction) -> Self { Self { $0.refraction = value.cssValue } }
    static func solidFill<S: ShapeStyle>(_ value: S) -> Self { Self { $0.solidFill = resolvedCSSValue(value) } }
    func tint<S: ShapeStyle>(_ value: S) -> Self { appending(Self.tint(value)) }
    func opacity(_ value: Double) -> Self { appending(Self.opacity(value)) }
    func opacityStep(_ value: Double) -> Self { appending(Self.opacityStep(value)) }
    func blur(_ value: Length) -> Self { appending(Self.blur(value)) }
    func saturate(_ value: Double) -> Self { appending(Self.saturate(value)) }
    func brightness(_ value: Double) -> Self { appending(Self.brightness(value)) }
    func rim(_ value: ThemeShadow) -> Self { appending(Self.rim(value)) }
    func refraction(_ value: ThemeRefraction) -> Self { appending(Self.refraction(value)) }
    func solidFill<S: ShapeStyle>(_ value: S) -> Self { appending(Self.solidFill(value)) }
}
