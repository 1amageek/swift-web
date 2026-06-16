@dynamicMemberLookup
public struct DesignStyleRootOverrideStep {
    private let applyOverride: (inout DesignStyle.Root.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Root.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Root.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Root.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Root.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleRootBuilder {
    public static func buildBlock(_ components: DesignStyleRootOverrideStep...) -> [DesignStyleRootOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleRootOverrideStep) -> DesignStyleRootOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleRootOverrideStep]?) -> [DesignStyleRootOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleRootOverrideStep]) -> [DesignStyleRootOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleRootOverrideStep]) -> [DesignStyleRootOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleRootOverrideStep]]) -> [DesignStyleRootOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleRootOverrideStep {
    static func pageInlinePadding(_ value: String) -> Self { Self { $0.pageInlinePadding = value } }
    static func stackSpacing(_ value: String) -> Self { Self { $0.stackSpacing = value } }
}

@dynamicMemberLookup
public struct DesignStyleLayoutOverrideStep {
    private let applyOverride: (inout DesignStyle.Layout.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Layout.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Layout.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Layout.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Layout.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleLayoutBuilder {
    public static func buildBlock(_ components: DesignStyleLayoutOverrideStep...) -> [DesignStyleLayoutOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleLayoutOverrideStep) -> DesignStyleLayoutOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleLayoutOverrideStep]?) -> [DesignStyleLayoutOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleLayoutOverrideStep]) -> [DesignStyleLayoutOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleLayoutOverrideStep]) -> [DesignStyleLayoutOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleLayoutOverrideStep]]) -> [DesignStyleLayoutOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleLayoutOverrideStep {
    static func lazyIntrinsicSize(_ value: String) -> Self { Self { $0.lazyIntrinsicSize = value } }
}

@dynamicMemberLookup
public struct DesignStyleSurfaceOverrideStep {
    private let applyOverride: (inout DesignStyle.Surface.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Surface.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Surface.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Surface.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Surface.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleSurfaceBuilder {
    public static func buildBlock(_ components: DesignStyleSurfaceOverrideStep...) -> [DesignStyleSurfaceOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleSurfaceOverrideStep) -> DesignStyleSurfaceOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleSurfaceOverrideStep]?) -> [DesignStyleSurfaceOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleSurfaceOverrideStep]) -> [DesignStyleSurfaceOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleSurfaceOverrideStep]) -> [DesignStyleSurfaceOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleSurfaceOverrideStep]]) -> [DesignStyleSurfaceOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleSurfaceOverrideStep {
    static func cardBackground(_ value: String) -> Self { Self { $0.cardBackground = value } }
    static func cardBorder(_ value: String) -> Self { Self { $0.cardBorder = value } }
    static func cardRadius(_ value: String) -> Self { Self { $0.cardRadius = value } }
    static func cardShadow(_ value: String) -> Self { Self { $0.cardShadow = value } }
    static func cardBackdropFilter(_ value: String) -> Self { Self { $0.cardBackdropFilter = value } }
}

@dynamicMemberLookup
public struct DesignStyleTypographyOverrideStep {
    private let applyOverride: (inout DesignStyle.Typography.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Typography.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Typography.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Typography.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Typography.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleTypographyBuilder {
    public static func buildBlock(_ components: DesignStyleTypographyOverrideStep...) -> [DesignStyleTypographyOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleTypographyOverrideStep) -> DesignStyleTypographyOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleTypographyOverrideStep]?) -> [DesignStyleTypographyOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleTypographyOverrideStep]) -> [DesignStyleTypographyOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleTypographyOverrideStep]) -> [DesignStyleTypographyOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleTypographyOverrideStep]]) -> [DesignStyleTypographyOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleTypographyOverrideStep {
    static func pageHeadingSize(_ value: String) -> Self { Self { $0.pageHeadingSize = value } }
    static func pageHeadingLineHeight(_ value: String) -> Self { Self { $0.pageHeadingLineHeight = value } }
    static func sectionHeadingSize(_ value: String) -> Self { Self { $0.sectionHeadingSize = value } }
    static func subsectionHeadingSize(_ value: String) -> Self { Self { $0.subsectionHeadingSize = value } }
}

@dynamicMemberLookup
public struct DesignStyleControlOverrideStep {
    private let applyOverride: (inout DesignStyle.Control.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Control.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Control.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Control.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Control.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleControlBuilder {
    public static func buildBlock(_ components: DesignStyleControlOverrideStep...) -> [DesignStyleControlOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleControlOverrideStep) -> DesignStyleControlOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleControlOverrideStep]?) -> [DesignStyleControlOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleControlOverrideStep]) -> [DesignStyleControlOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleControlOverrideStep]) -> [DesignStyleControlOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleControlOverrideStep]]) -> [DesignStyleControlOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleControlOverrideStep {
    static func miniHeight(_ value: String) -> Self { Self { $0.miniHeight = value } }
    static func smallHeight(_ value: String) -> Self { Self { $0.smallHeight = value } }
    static func regularHeight(_ value: String) -> Self { Self { $0.regularHeight = value } }
    static func largeHeight(_ value: String) -> Self { Self { $0.largeHeight = value } }
    static func disabledOpacity(_ value: String) -> Self { Self { $0.disabledOpacity = value } }
}

@dynamicMemberLookup
public struct DesignStyleButtonOverrideStep {
    private let applyOverride: (inout DesignStyle.Button.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Button.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Button.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Button.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Button.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleButtonBuilder {
    public static func buildBlock(_ components: DesignStyleButtonOverrideStep...) -> [DesignStyleButtonOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleButtonOverrideStep) -> DesignStyleButtonOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleButtonOverrideStep]?) -> [DesignStyleButtonOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleButtonOverrideStep]) -> [DesignStyleButtonOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleButtonOverrideStep]) -> [DesignStyleButtonOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleButtonOverrideStep]]) -> [DesignStyleButtonOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleButtonOverrideStep {
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
public struct DesignStyleFieldOverrideStep {
    private let applyOverride: (inout DesignStyle.Field.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Field.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Field.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Field.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Field.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleFieldBuilder {
    public static func buildBlock(_ components: DesignStyleFieldOverrideStep...) -> [DesignStyleFieldOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleFieldOverrideStep) -> DesignStyleFieldOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleFieldOverrideStep]?) -> [DesignStyleFieldOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleFieldOverrideStep]) -> [DesignStyleFieldOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleFieldOverrideStep]) -> [DesignStyleFieldOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleFieldOverrideStep]]) -> [DesignStyleFieldOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleFieldOverrideStep {
    static func background(_ value: String) -> Self { Self { $0.background = value } }
    static func border(_ value: String) -> Self { Self { $0.border = value } }
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func padding(_ value: String) -> Self { Self { $0.padding = value } }
    static func labelSize(_ value: String) -> Self { Self { $0.labelSize = value } }
}

@dynamicMemberLookup
public struct DesignStyleBadgeOverrideStep {
    private let applyOverride: (inout DesignStyle.Badge.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Badge.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Badge.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Badge.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Badge.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleBadgeBuilder {
    public static func buildBlock(_ components: DesignStyleBadgeOverrideStep...) -> [DesignStyleBadgeOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleBadgeOverrideStep) -> DesignStyleBadgeOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleBadgeOverrideStep]?) -> [DesignStyleBadgeOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleBadgeOverrideStep]) -> [DesignStyleBadgeOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleBadgeOverrideStep]) -> [DesignStyleBadgeOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleBadgeOverrideStep]]) -> [DesignStyleBadgeOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleBadgeOverrideStep {
    static func background(_ value: String) -> Self { Self { $0.background = value } }
    static func border(_ value: String) -> Self { Self { $0.border = value } }
    static func foreground(_ value: String) -> Self { Self { $0.foreground = value } }
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func padding(_ value: String) -> Self { Self { $0.padding = value } }
}

@dynamicMemberLookup
public struct DesignStyleValueDisplayOverrideStep {
    private let applyOverride: (inout DesignStyle.ValueDisplay.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.ValueDisplay.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.ValueDisplay.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.ValueDisplay.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.ValueDisplay.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleValueDisplayBuilder {
    public static func buildBlock(_ components: DesignStyleValueDisplayOverrideStep...) -> [DesignStyleValueDisplayOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleValueDisplayOverrideStep) -> DesignStyleValueDisplayOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleValueDisplayOverrideStep]?) -> [DesignStyleValueDisplayOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleValueDisplayOverrideStep]) -> [DesignStyleValueDisplayOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleValueDisplayOverrideStep]) -> [DesignStyleValueDisplayOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleValueDisplayOverrideStep]]) -> [DesignStyleValueDisplayOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleValueDisplayOverrideStep {
    static func background(_ value: String) -> Self { Self { $0.background = value } }
    static func border(_ value: String) -> Self { Self { $0.border = value } }
    static func radius(_ value: String) -> Self { Self { $0.radius = value } }
    static func padding(_ value: String) -> Self { Self { $0.padding = value } }
    static func valueSize(_ value: String) -> Self { Self { $0.valueSize = value } }
    static func valueWeight(_ value: String) -> Self { Self { $0.valueWeight = value } }
}

@dynamicMemberLookup
public struct DesignStyleNavigationOverrideStep {
    private let applyOverride: (inout DesignStyle.Navigation.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Navigation.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Navigation.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Navigation.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Navigation.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleNavigationBuilder {
    public static func buildBlock(_ components: DesignStyleNavigationOverrideStep...) -> [DesignStyleNavigationOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleNavigationOverrideStep) -> DesignStyleNavigationOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleNavigationOverrideStep]?) -> [DesignStyleNavigationOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleNavigationOverrideStep]) -> [DesignStyleNavigationOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleNavigationOverrideStep]) -> [DesignStyleNavigationOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleNavigationOverrideStep]]) -> [DesignStyleNavigationOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleNavigationOverrideStep {
    static func gap(_ value: String) -> Self { Self { $0.gap = value } }
    static func linkForeground(_ value: String) -> Self { Self { $0.linkForeground = value } }
    static func linkDecoration(_ value: String) -> Self { Self { $0.linkDecoration = value } }
    static func linkHoverDecoration(_ value: String) -> Self { Self { $0.linkHoverDecoration = value } }
}

@dynamicMemberLookup
public struct DesignStyleToggleOverrideStep {
    private let applyOverride: (inout DesignStyle.Toggle.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Toggle.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Toggle.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Toggle.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Toggle.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleToggleBuilder {
    public static func buildBlock(_ components: DesignStyleToggleOverrideStep...) -> [DesignStyleToggleOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleToggleOverrideStep) -> DesignStyleToggleOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleToggleOverrideStep]?) -> [DesignStyleToggleOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleToggleOverrideStep]) -> [DesignStyleToggleOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleToggleOverrideStep]) -> [DesignStyleToggleOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleToggleOverrideStep]]) -> [DesignStyleToggleOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleToggleOverrideStep {
    static func width(_ value: String) -> Self { Self { $0.width = value } }
    static func height(_ value: String) -> Self { Self { $0.height = value } }
    static func thumbSize(_ value: String) -> Self { Self { $0.thumbSize = value } }
    static func thumbOffset(_ value: String) -> Self { Self { $0.thumbOffset = value } }
    static func checkedThumbOffset(_ value: String) -> Self { Self { $0.checkedThumbOffset = value } }
}

@dynamicMemberLookup
public struct DesignStyleMotionOverrideStep {
    private let applyOverride: (inout DesignStyle.Motion.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Motion.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Motion.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Motion.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Motion.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleMotionBuilder {
    public static func buildBlock(_ components: DesignStyleMotionOverrideStep...) -> [DesignStyleMotionOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleMotionOverrideStep) -> DesignStyleMotionOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleMotionOverrideStep]?) -> [DesignStyleMotionOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleMotionOverrideStep]) -> [DesignStyleMotionOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleMotionOverrideStep]) -> [DesignStyleMotionOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleMotionOverrideStep]]) -> [DesignStyleMotionOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleMotionOverrideStep {
    static func quick(_ value: String) -> Self { Self { $0.quick = value } }
    static func standard(_ value: String) -> Self { Self { $0.standard = value } }
}

@dynamicMemberLookup
public struct DesignStyleMaterialOverrideStep {
    private let applyOverride: (inout DesignStyle.Material.Override) -> Void
    public init(_ applyOverride: @escaping (inout DesignStyle.Material.Override) -> Void) { self.applyOverride = applyOverride }
    public func apply(to override: inout DesignStyle.Material.Override) { applyOverride(&override) }
    public func appending(_ step: Self) -> Self {
        Self { override in
            self.apply(to: &override)
            step.apply(to: &override)
        }
    }
    public static subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Material.Override, String?>) -> (String) -> Self {
        { value in Self { $0[keyPath: keyPath] = value } }
    }
    public subscript(dynamicMember keyPath: WritableKeyPath<DesignStyle.Material.Override, String?>) -> (String) -> Self {
        { value in self.appending(Self { $0[keyPath: keyPath] = value }) }
    }
}

@resultBuilder
public enum DesignStyleMaterialBuilder {
    public static func buildBlock(_ components: DesignStyleMaterialOverrideStep...) -> [DesignStyleMaterialOverrideStep] { components }
    public static func buildExpression(_ expression: DesignStyleMaterialOverrideStep) -> DesignStyleMaterialOverrideStep { expression }
    public static func buildOptional(_ component: [DesignStyleMaterialOverrideStep]?) -> [DesignStyleMaterialOverrideStep] { component ?? [] }
    public static func buildEither(first component: [DesignStyleMaterialOverrideStep]) -> [DesignStyleMaterialOverrideStep] { component }
    public static func buildEither(second component: [DesignStyleMaterialOverrideStep]) -> [DesignStyleMaterialOverrideStep] { component }
    public static func buildArray(_ components: [[DesignStyleMaterialOverrideStep]]) -> [DesignStyleMaterialOverrideStep] { components.flatMap { $0 } }
}

public extension DesignStyleMaterialOverrideStep {
    static func solidBackground(_ value: String) -> Self { Self { $0.solidBackground = value } }
    static func elevatedBackground(_ value: String) -> Self { Self { $0.elevatedBackground = value } }
    static func glassBackground(_ value: String) -> Self { Self { $0.glassBackground = value } }
    static func glassBorder(_ value: String) -> Self { Self { $0.glassBorder = value } }
    static func glassShadow(_ value: String) -> Self { Self { $0.glassShadow = value } }
    static func glassBackdropFilter(_ value: String) -> Self { Self { $0.glassBackdropFilter = value } }
}
