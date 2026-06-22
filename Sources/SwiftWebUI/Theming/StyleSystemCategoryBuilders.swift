public struct StyleSystemRootOverrideStep {
    private let applyOverride: (inout StyleSystem.Root.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Root.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Root.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemRootBuilder {
    public static func buildBlock(_ components: StyleSystemRootOverrideStep...) -> [StyleSystemRootOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemRootOverrideStep) -> StyleSystemRootOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemRootOverrideStep]?) -> [StyleSystemRootOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemRootOverrideStep]) -> [StyleSystemRootOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemRootOverrideStep]) -> [StyleSystemRootOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemRootOverrideStep]]) -> [StyleSystemRootOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemRootOverrideStep {
    static func pageInlinePadding(_ value: Length) -> Self { Self { $0.pageInlinePadding = value.cssValue } }
    static func stackSpacing(_ value: Space) -> Self { Self { $0.stackSpacing = value.rawValue } }
    static func stackSpacing(_ value: Length) -> Self { Self { $0.stackSpacing = value.cssValue } }
    func pageInlinePadding(_ value: Length) -> Self { appending(Self.pageInlinePadding(value)) }
    func stackSpacing(_ value: Space) -> Self { appending(Self.stackSpacing(value)) }
    func stackSpacing(_ value: Length) -> Self { appending(Self.stackSpacing(value)) }
}

public struct StyleSystemLayoutOverrideStep {
    private let applyOverride: (inout StyleSystem.Layout.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Layout.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Layout.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemLayoutBuilder {
    public static func buildBlock(_ components: StyleSystemLayoutOverrideStep...) -> [StyleSystemLayoutOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemLayoutOverrideStep) -> StyleSystemLayoutOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemLayoutOverrideStep]?) -> [StyleSystemLayoutOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemLayoutOverrideStep]) -> [StyleSystemLayoutOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemLayoutOverrideStep]) -> [StyleSystemLayoutOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemLayoutOverrideStep]]) -> [StyleSystemLayoutOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemLayoutOverrideStep {
    static func lazyIntrinsicSize(_ value: StyleSystemIntrinsicSize) -> Self { Self { $0.lazyIntrinsicSize = value.cssValue } }
    func lazyIntrinsicSize(_ value: StyleSystemIntrinsicSize) -> Self { appending(Self.lazyIntrinsicSize(value)) }
}

public struct StyleSystemSurfaceOverrideStep {
    private let applyOverride: (inout StyleSystem.Surface.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Surface.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Surface.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemSurfaceBuilder {
    public static func buildBlock(_ components: StyleSystemSurfaceOverrideStep...) -> [StyleSystemSurfaceOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemSurfaceOverrideStep) -> StyleSystemSurfaceOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemSurfaceOverrideStep]?) -> [StyleSystemSurfaceOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemSurfaceOverrideStep]) -> [StyleSystemSurfaceOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemSurfaceOverrideStep]) -> [StyleSystemSurfaceOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemSurfaceOverrideStep]]) -> [StyleSystemSurfaceOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemSurfaceOverrideStep {
    static func containerBorder(_ value: StyleSystemBorder) -> Self { Self { $0.containerBorder = value.cssValue } }
    static func containerRadius(_ value: Length) -> Self { Self { $0.containerRadius = value.cssValue } }
    static func containerShadow(_ value: StyleSystemShadow) -> Self { Self { $0.containerShadow = value.cssValue } }
    func containerBorder(_ value: StyleSystemBorder) -> Self { appending(Self.containerBorder(value)) }
    func containerRadius(_ value: Length) -> Self { appending(Self.containerRadius(value)) }
    func containerShadow(_ value: StyleSystemShadow) -> Self { appending(Self.containerShadow(value)) }
}

public struct StyleSystemTypographyOverrideStep {
    private let applyOverride: (inout StyleSystem.Typography.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Typography.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Typography.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemTypographyBuilder {
    public static func buildBlock(_ components: StyleSystemTypographyOverrideStep...) -> [StyleSystemTypographyOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemTypographyOverrideStep) -> StyleSystemTypographyOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemTypographyOverrideStep]?) -> [StyleSystemTypographyOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemTypographyOverrideStep]) -> [StyleSystemTypographyOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemTypographyOverrideStep]) -> [StyleSystemTypographyOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemTypographyOverrideStep]]) -> [StyleSystemTypographyOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemTypographyOverrideStep {
    static func pageHeadingSize(_ value: Length) -> Self { Self { $0.pageHeadingSize = value.cssValue } }
    static func pageHeadingLineHeight(_ value: Double) -> Self { Self { $0.pageHeadingLineHeight = trimmedNumber(value) } }
    static func sectionHeadingSize(_ value: Length) -> Self { Self { $0.sectionHeadingSize = value.cssValue } }
    static func subsectionHeadingSize(_ value: Length) -> Self { Self { $0.subsectionHeadingSize = value.cssValue } }
    func pageHeadingSize(_ value: Length) -> Self { appending(Self.pageHeadingSize(value)) }
    func pageHeadingLineHeight(_ value: Double) -> Self { appending(Self.pageHeadingLineHeight(value)) }
    func sectionHeadingSize(_ value: Length) -> Self { appending(Self.sectionHeadingSize(value)) }
    func subsectionHeadingSize(_ value: Length) -> Self { appending(Self.subsectionHeadingSize(value)) }
}

public struct StyleSystemControlOverrideStep {
    private let applyOverride: (inout StyleSystem.Control.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Control.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Control.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemControlBuilder {
    public static func buildBlock(_ components: StyleSystemControlOverrideStep...) -> [StyleSystemControlOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemControlOverrideStep) -> StyleSystemControlOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemControlOverrideStep]?) -> [StyleSystemControlOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemControlOverrideStep]) -> [StyleSystemControlOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemControlOverrideStep]) -> [StyleSystemControlOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemControlOverrideStep]]) -> [StyleSystemControlOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemControlOverrideStep {
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

public struct StyleSystemButtonOverrideStep {
    private let applyOverride: (inout StyleSystem.Button.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Button.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Button.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemButtonBuilder {
    public static func buildBlock(_ components: StyleSystemButtonOverrideStep...) -> [StyleSystemButtonOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemButtonOverrideStep) -> StyleSystemButtonOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemButtonOverrideStep]?) -> [StyleSystemButtonOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemButtonOverrideStep]) -> [StyleSystemButtonOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemButtonOverrideStep]) -> [StyleSystemButtonOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemButtonOverrideStep]]) -> [StyleSystemButtonOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemButtonOverrideStep {
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func primaryBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.primaryBackground = styleSystemCSSValue(value) } }
    static func primaryForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.primaryForeground = styleSystemCSSValue(value) } }
    static func secondaryBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.secondaryBackground = styleSystemCSSValue(value) } }
    static func secondaryForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.secondaryForeground = styleSystemCSSValue(value) } }
    static func secondaryBorder<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.secondaryBorder = styleSystemCSSValue(value) } }
    static func secondaryHoverBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.secondaryHoverBackground = styleSystemCSSValue(value) } }
    static func plainForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.plainForeground = styleSystemCSSValue(value) } }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func primaryBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.primaryBackground(value)) }
    func primaryForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.primaryForeground(value)) }
    func secondaryBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.secondaryBackground(value)) }
    func secondaryForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.secondaryForeground(value)) }
    func secondaryBorder<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.secondaryBorder(value)) }
    func secondaryHoverBackground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.secondaryHoverBackground(value)) }
    func plainForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.plainForeground(value)) }
}

public struct StyleSystemFieldOverrideStep {
    private let applyOverride: (inout StyleSystem.Field.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Field.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Field.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemFieldBuilder {
    public static func buildBlock(_ components: StyleSystemFieldOverrideStep...) -> [StyleSystemFieldOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemFieldOverrideStep) -> StyleSystemFieldOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemFieldOverrideStep]?) -> [StyleSystemFieldOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemFieldOverrideStep]) -> [StyleSystemFieldOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemFieldOverrideStep]) -> [StyleSystemFieldOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemFieldOverrideStep]]) -> [StyleSystemFieldOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemFieldOverrideStep {
    static func background<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.background = styleSystemCSSValue(value) } }
    static func border(_ value: StyleSystemBorder) -> Self { Self { $0.border = value.cssValue } }
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func padding(_ value: EdgeInsets) -> Self { Self { $0.padding = value.cssValue } }
    static func padding(vertical: Length, horizontal: Length) -> Self {
        Self { $0.padding = "\(vertical.cssValue) \(horizontal.cssValue)" }
    }
    static func labelSize(_ value: Length) -> Self { Self { $0.labelSize = value.cssValue } }
    func background<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.background(value)) }
    func border(_ value: StyleSystemBorder) -> Self { appending(Self.border(value)) }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func padding(_ value: EdgeInsets) -> Self { appending(Self.padding(value)) }
    func padding(vertical: Length, horizontal: Length) -> Self { appending(Self.padding(vertical: vertical, horizontal: horizontal)) }
    func labelSize(_ value: Length) -> Self { appending(Self.labelSize(value)) }
}

public struct StyleSystemBadgeOverrideStep {
    private let applyOverride: (inout StyleSystem.Badge.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Badge.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Badge.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemBadgeBuilder {
    public static func buildBlock(_ components: StyleSystemBadgeOverrideStep...) -> [StyleSystemBadgeOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemBadgeOverrideStep) -> StyleSystemBadgeOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemBadgeOverrideStep]?) -> [StyleSystemBadgeOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemBadgeOverrideStep]) -> [StyleSystemBadgeOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemBadgeOverrideStep]) -> [StyleSystemBadgeOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemBadgeOverrideStep]]) -> [StyleSystemBadgeOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemBadgeOverrideStep {
    static func background<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.background = styleSystemCSSValue(value) } }
    static func border(_ value: StyleSystemBorder) -> Self { Self { $0.border = value.cssValue } }
    static func foreground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.foreground = styleSystemCSSValue(value) } }
    static func radius(_ value: Length) -> Self { Self { $0.radius = value.cssValue } }
    static func padding(_ value: EdgeInsets) -> Self { Self { $0.padding = value.cssValue } }
    static func padding(vertical: Length, horizontal: Length) -> Self {
        Self { $0.padding = "\(vertical.cssValue) \(horizontal.cssValue)" }
    }
    func background<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.background(value)) }
    func border(_ value: StyleSystemBorder) -> Self { appending(Self.border(value)) }
    func foreground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.foreground(value)) }
    func radius(_ value: Length) -> Self { appending(Self.radius(value)) }
    func padding(_ value: EdgeInsets) -> Self { appending(Self.padding(value)) }
    func padding(vertical: Length, horizontal: Length) -> Self { appending(Self.padding(vertical: vertical, horizontal: horizontal)) }
}

public struct StyleSystemNavigationOverrideStep {
    private let applyOverride: (inout StyleSystem.Navigation.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Navigation.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Navigation.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemNavigationBuilder {
    public static func buildBlock(_ components: StyleSystemNavigationOverrideStep...) -> [StyleSystemNavigationOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemNavigationOverrideStep) -> StyleSystemNavigationOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemNavigationOverrideStep]?) -> [StyleSystemNavigationOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemNavigationOverrideStep]) -> [StyleSystemNavigationOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemNavigationOverrideStep]) -> [StyleSystemNavigationOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemNavigationOverrideStep]]) -> [StyleSystemNavigationOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemNavigationOverrideStep {
    static func gap(_ value: Space) -> Self { Self { $0.gap = value.rawValue } }
    static func gap(_ value: Length) -> Self { Self { $0.gap = value.cssValue } }
    static func linkForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.linkForeground = styleSystemCSSValue(value) } }
    static func linkDecoration(_ value: StyleSystemTextDecoration) -> Self { Self { $0.linkDecoration = value.cssValue } }
    static func linkHoverDecoration(_ value: StyleSystemTextDecoration) -> Self { Self { $0.linkHoverDecoration = value.cssValue } }
    func gap(_ value: Space) -> Self { appending(Self.gap(value)) }
    func gap(_ value: Length) -> Self { appending(Self.gap(value)) }
    func linkForeground<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.linkForeground(value)) }
    func linkDecoration(_ value: StyleSystemTextDecoration) -> Self { appending(Self.linkDecoration(value)) }
    func linkHoverDecoration(_ value: StyleSystemTextDecoration) -> Self { appending(Self.linkHoverDecoration(value)) }
}

public struct StyleSystemToggleOverrideStep {
    private let applyOverride: (inout StyleSystem.Toggle.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Toggle.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Toggle.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemToggleBuilder {
    public static func buildBlock(_ components: StyleSystemToggleOverrideStep...) -> [StyleSystemToggleOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemToggleOverrideStep) -> StyleSystemToggleOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemToggleOverrideStep]?) -> [StyleSystemToggleOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemToggleOverrideStep]) -> [StyleSystemToggleOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemToggleOverrideStep]) -> [StyleSystemToggleOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemToggleOverrideStep]]) -> [StyleSystemToggleOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemToggleOverrideStep {
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

public struct StyleSystemMotionOverrideStep {
    private let applyOverride: (inout StyleSystem.Motion.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Motion.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Motion.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemMotionBuilder {
    public static func buildBlock(_ components: StyleSystemMotionOverrideStep...) -> [StyleSystemMotionOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemMotionOverrideStep) -> StyleSystemMotionOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemMotionOverrideStep]?) -> [StyleSystemMotionOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemMotionOverrideStep]) -> [StyleSystemMotionOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemMotionOverrideStep]) -> [StyleSystemMotionOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemMotionOverrideStep]]) -> [StyleSystemMotionOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemMotionOverrideStep {
    static func quick(_ value: StyleSystemMotionTiming) -> Self { Self { $0.quick = value.cssValue } }
    static func standard(_ value: StyleSystemMotionTiming) -> Self { Self { $0.standard = value.cssValue } }
    func quick(_ value: StyleSystemMotionTiming) -> Self { appending(Self.quick(value)) }
    func standard(_ value: StyleSystemMotionTiming) -> Self { appending(Self.standard(value)) }
}

public struct StyleSystemMaterialOverrideStep {
    private let applyOverride: (inout StyleSystem.Material.Override) -> Void
    init(_ applyOverride: @escaping (inout StyleSystem.Material.Override) -> Void) { self.applyOverride = applyOverride }
    func apply(to override: inout StyleSystem.Material.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
}

@resultBuilder
public enum StyleSystemMaterialBuilder {
    public static func buildBlock(_ components: StyleSystemMaterialOverrideStep...) -> [StyleSystemMaterialOverrideStep] { components }
    public static func buildExpression(_ expression: StyleSystemMaterialOverrideStep) -> StyleSystemMaterialOverrideStep { expression }
    public static func buildOptional(_ component: [StyleSystemMaterialOverrideStep]?) -> [StyleSystemMaterialOverrideStep] { component ?? [] }
    public static func buildEither(first component: [StyleSystemMaterialOverrideStep]) -> [StyleSystemMaterialOverrideStep] { component }
    public static func buildEither(second component: [StyleSystemMaterialOverrideStep]) -> [StyleSystemMaterialOverrideStep] { component }
    public static func buildArray(_ components: [[StyleSystemMaterialOverrideStep]]) -> [StyleSystemMaterialOverrideStep] { components.flatMap { $0 } }
}

public extension StyleSystemMaterialOverrideStep {
    static func tint<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.tint = styleSystemCSSValue(value) } }
    static func opacity(_ value: Double) -> Self { Self { $0.opacity = trimmedNumber(value) } }
    static func opacityStep(_ value: Double) -> Self { Self { $0.opacityStep = trimmedNumber(value) } }
    static func blur(_ value: Length) -> Self { Self { $0.blur = value.cssValue } }
    static func saturate(_ value: Double) -> Self { Self { $0.saturate = trimmedNumber(value) } }
    static func brightness(_ value: Double) -> Self { Self { $0.brightness = trimmedNumber(value) } }
    static func rim(_ value: StyleSystemShadow) -> Self { Self { $0.rim = value.cssValue } }
    static func refraction(_ value: StyleSystemRefraction) -> Self { Self { $0.refraction = value.cssValue } }
    static func solidFill<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { Self { $0.solidFill = styleSystemCSSValue(value) } }
    func tint<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.tint(value)) }
    func opacity(_ value: Double) -> Self { appending(Self.opacity(value)) }
    func opacityStep(_ value: Double) -> Self { appending(Self.opacityStep(value)) }
    func blur(_ value: Length) -> Self { appending(Self.blur(value)) }
    func saturate(_ value: Double) -> Self { appending(Self.saturate(value)) }
    func brightness(_ value: Double) -> Self { appending(Self.brightness(value)) }
    func rim(_ value: StyleSystemShadow) -> Self { appending(Self.rim(value)) }
    func refraction(_ value: StyleSystemRefraction) -> Self { appending(Self.refraction(value)) }
    func solidFill<ShapeStyle: WebShapeStyle>(_ value: ShapeStyle) -> Self { appending(Self.solidFill(value)) }
}
