@dynamicMemberLookup
public struct StyleSystemRootOverrideStep {
    private let applyOverride: (inout StyleSystem.Root.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Root.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Root.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Root.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Root.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func pageInlinePadding(_ value: String) -> Self { Self { $0.pageInlinePadding = value } }
    static func stackSpacing(_ value: String) -> Self { Self { $0.stackSpacing = value } }
}

@dynamicMemberLookup
public struct StyleSystemLayoutOverrideStep {
    private let applyOverride: (inout StyleSystem.Layout.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Layout.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Layout.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Layout.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Layout.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func lazyIntrinsicSize(_ value: String) -> Self { Self { $0.lazyIntrinsicSize = value } }
}

@dynamicMemberLookup
public struct StyleSystemSurfaceOverrideStep {
    private let applyOverride: (inout StyleSystem.Surface.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Surface.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Surface.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Surface.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Surface.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func containerBorder(_ value: String) -> Self { Self { $0.containerBorder = value } }
    static func containerRadius(_ value: String) -> Self { Self { $0.containerRadius = value } }
    static func containerShadow(_ value: String) -> Self { Self { $0.containerShadow = value } }
}

@dynamicMemberLookup
public struct StyleSystemTypographyOverrideStep {
    private let applyOverride: (inout StyleSystem.Typography.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Typography.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Typography.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Typography.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Typography.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func pageHeadingSize(_ value: String) -> Self { Self { $0.pageHeadingSize = value } }
    static func pageHeadingLineHeight(_ value: String) -> Self { Self { $0.pageHeadingLineHeight = value } }
    static func sectionHeadingSize(_ value: String) -> Self { Self { $0.sectionHeadingSize = value } }
    static func subsectionHeadingSize(_ value: String) -> Self { Self { $0.subsectionHeadingSize = value } }
}

@dynamicMemberLookup
public struct StyleSystemControlOverrideStep {
    private let applyOverride: (inout StyleSystem.Control.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Control.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Control.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Control.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Control.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func miniHeight(_ value: String) -> Self { Self { $0.miniHeight = value } }
    static func smallHeight(_ value: String) -> Self { Self { $0.smallHeight = value } }
    static func regularHeight(_ value: String) -> Self { Self { $0.regularHeight = value } }
    static func largeHeight(_ value: String) -> Self { Self { $0.largeHeight = value } }
    static func disabledOpacity(_ value: String) -> Self { Self { $0.disabledOpacity = value } }
}

@dynamicMemberLookup
public struct StyleSystemButtonOverrideStep {
    private let applyOverride: (inout StyleSystem.Button.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Button.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Button.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Button.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Button.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func primaryBackground(_ value: String) -> Self { Self { $0.primaryBackground = value } }
    static func primaryForeground(_ value: String) -> Self { Self { $0.primaryForeground = value } }
    static func secondaryBackground(_ value: String) -> Self { Self { $0.secondaryBackground = value } }
    static func secondaryForeground(_ value: String) -> Self { Self { $0.secondaryForeground = value } }
    static func secondaryBorder(_ value: String) -> Self { Self { $0.secondaryBorder = value } }
    static func secondaryHoverBackground(_ value: String) -> Self { Self { $0.secondaryHoverBackground = value } }
    static func plainForeground(_ value: String) -> Self { Self { $0.plainForeground = value } }
}

@dynamicMemberLookup
public struct StyleSystemFieldOverrideStep {
    private let applyOverride: (inout StyleSystem.Field.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Field.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Field.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Field.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Field.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func background(_ value: String) -> Self { Self { $0.background = value } }
    static func border(_ value: String) -> Self { Self { $0.border = value } }
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func padding(_ value: String) -> Self { Self { $0.padding = value } }
    static func labelSize(_ value: String) -> Self { Self { $0.labelSize = value } }
}

@dynamicMemberLookup
public struct StyleSystemBadgeOverrideStep {
    private let applyOverride: (inout StyleSystem.Badge.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Badge.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Badge.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Badge.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Badge.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func background(_ value: String) -> Self { Self { $0.background = value } }
    static func border(_ value: String) -> Self { Self { $0.border = value } }
    static func foreground(_ value: String) -> Self { Self { $0.foreground = value } }
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func padding(_ value: String) -> Self { Self { $0.padding = value } }
}

@dynamicMemberLookup
public struct StyleSystemNavigationOverrideStep {
    private let applyOverride: (inout StyleSystem.Navigation.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Navigation.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Navigation.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Navigation.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Navigation.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func gap(_ value: String) -> Self { Self { $0.gap = value } }
    static func linkForeground(_ value: String) -> Self { Self { $0.linkForeground = value } }
    static func linkDecoration(_ value: String) -> Self { Self { $0.linkDecoration = value } }
    static func linkHoverDecoration(_ value: String) -> Self { Self { $0.linkHoverDecoration = value } }
}

@dynamicMemberLookup
public struct StyleSystemToggleOverrideStep {
    private let applyOverride: (inout StyleSystem.Toggle.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Toggle.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Toggle.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Toggle.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Toggle.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func width(_ value: String) -> Self { Self { $0.width = value } }
    static func height(_ value: String) -> Self { Self { $0.height = value } }
    static func thumbSize(_ value: String) -> Self { Self { $0.thumbSize = value } }
    static func thumbOffset(_ value: String) -> Self { Self { $0.thumbOffset = value } }
    static func checkedThumbOffset(_ value: String) -> Self { Self { $0.checkedThumbOffset = value } }
}

@dynamicMemberLookup
public struct StyleSystemMotionOverrideStep {
    private let applyOverride: (inout StyleSystem.Motion.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Motion.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Motion.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Motion.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Motion.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func quick(_ value: String) -> Self { Self { $0.quick = value } }
    static func standard(_ value: String) -> Self { Self { $0.standard = value } }
}

@dynamicMemberLookup
public struct StyleSystemMaterialOverrideStep {
    private let applyOverride: (inout StyleSystem.Material.Override) -> Void
    public init(_ applyOverride: @escaping (inout StyleSystem.Material.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout StyleSystem.Material.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Material.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<StyleSystem.Material.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
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
    static func tint(_ value: String) -> Self { Self { $0.tint = value } }
    static func opacity(_ value: String) -> Self { Self { $0.opacity = value } }
    static func opacityStep(_ value: String) -> Self { Self { $0.opacityStep = value } }
    static func blur(_ value: String) -> Self { Self { $0.blur = value } }
    static func saturate(_ value: String) -> Self { Self { $0.saturate = value } }
    static func brightness(_ value: String) -> Self { Self { $0.brightness = value } }
    static func rim(_ value: String) -> Self { Self { $0.rim = value } }
    static func refraction(_ value: String) -> Self { Self { $0.refraction = value } }
    static func solidFill(_ value: String) -> Self { Self { $0.solidFill = value } }
}
