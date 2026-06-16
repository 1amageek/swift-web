import SwiftHTML

public struct StyleSystem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var root: Root
    public var layout: Layout
    public var surface: Surface
    public var typography: Typography
    public var control: Control
    public var button: Button
    public var field: Field
    public var badge: Badge
    public var valueDisplay: ValueDisplay
    public var navigation: Navigation
    public var toggle: Toggle
    public var motion: Motion
    public var material: Material

    public init(
        id: String,
        root: Root,
        layout: Layout,
        surface: Surface,
        typography: Typography,
        control: Control,
        button: Button,
        field: Field,
        badge: Badge,
        valueDisplay: ValueDisplay,
        navigation: Navigation,
        toggle: Toggle,
        motion: Motion,
        material: Material
    ) {
        self.id = id
        self.root = root
        self.layout = layout
        self.surface = surface
        self.typography = typography
        self.control = control
        self.button = button
        self.field = field
        self.badge = badge
        self.valueDisplay = valueDisplay
        self.navigation = navigation
        self.toggle = toggle
        self.motion = motion
        self.material = material
    }

    public func overriding(_ override: Override) -> StyleSystem {
        var style = self
        if let id = override.id {
            style.id = id
        }
        if let root = override.root {
            style.root = style.root.overriding(root)
        }
        if let layout = override.layout {
            style.layout = style.layout.overriding(layout)
        }
        if let surface = override.surface {
            style.surface = style.surface.overriding(surface)
        }
        if let typography = override.typography {
            style.typography = style.typography.overriding(typography)
        }
        if let control = override.control {
            style.control = style.control.overriding(control)
        }
        if let button = override.button {
            style.button = style.button.overriding(button)
        }
        if let field = override.field {
            style.field = style.field.overriding(field)
        }
        if let badge = override.badge {
            style.badge = style.badge.overriding(badge)
        }
        if let valueDisplay = override.valueDisplay {
            style.valueDisplay = style.valueDisplay.overriding(valueDisplay)
        }
        if let navigation = override.navigation {
            style.navigation = style.navigation.overriding(navigation)
        }
        if let toggle = override.toggle {
            style.toggle = style.toggle.overriding(toggle)
        }
        if let motion = override.motion {
            style.motion = style.motion.overriding(motion)
        }
        if let material = override.material {
            style.material = style.material.overriding(material)
        }
        return style
    }
}

public extension StyleSystem {
    struct Override: Codable, Sendable, Equatable {
        public var id: String?
        public var root: Root.Override?
        public var layout: Layout.Override?
        public var surface: Surface.Override?
        public var typography: Typography.Override?
        public var control: Control.Override?
        public var button: Button.Override?
        public var field: Field.Override?
        public var badge: Badge.Override?
        public var valueDisplay: ValueDisplay.Override?
        public var navigation: Navigation.Override?
        public var toggle: Toggle.Override?
        public var motion: Motion.Override?
        public var material: Material.Override?

        public init(
            id: String? = nil,
            root: Root.Override? = nil,
            layout: Layout.Override? = nil,
            surface: Surface.Override? = nil,
            typography: Typography.Override? = nil,
            control: Control.Override? = nil,
            button: Button.Override? = nil,
            field: Field.Override? = nil,
            badge: Badge.Override? = nil,
            valueDisplay: ValueDisplay.Override? = nil,
            navigation: Navigation.Override? = nil,
            toggle: Toggle.Override? = nil,
            motion: Motion.Override? = nil,
            material: Material.Override? = nil
        ) {
            self.id = id
            self.root = root
            self.layout = layout
            self.surface = surface
            self.typography = typography
            self.control = control
            self.button = button
            self.field = field
            self.badge = badge
            self.valueDisplay = valueDisplay
            self.navigation = navigation
            self.toggle = toggle
            self.motion = motion
            self.material = material
        }
    }

    struct Root: Codable, Sendable, Equatable {
        public var pageInlinePadding: String
        public var stackSpacing: String

        public init(pageInlinePadding: String, stackSpacing: String) {
            self.pageInlinePadding = pageInlinePadding
            self.stackSpacing = stackSpacing
        }

        public func overriding(_ override: Override) -> Root {
            Root(
                pageInlinePadding: override.pageInlinePadding ?? pageInlinePadding,
                stackSpacing: override.stackSpacing ?? stackSpacing
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var pageInlinePadding: String?
            public var stackSpacing: String?

            public init(pageInlinePadding: String? = nil, stackSpacing: String? = nil) {
                self.pageInlinePadding = pageInlinePadding
                self.stackSpacing = stackSpacing
            }
        }
    }

    struct Layout: Codable, Sendable, Equatable {
        public var lazyIntrinsicSize: String

        public init(lazyIntrinsicSize: String) {
            self.lazyIntrinsicSize = lazyIntrinsicSize
        }

        public func overriding(_ override: Override) -> Layout {
            Layout(
                lazyIntrinsicSize: override.lazyIntrinsicSize ?? lazyIntrinsicSize
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var lazyIntrinsicSize: String?

            public init(lazyIntrinsicSize: String? = nil) {
                self.lazyIntrinsicSize = lazyIntrinsicSize
            }
        }
    }

    struct Surface: Codable, Sendable, Equatable {
        // The card fill and backdrop are owned by the `Material` primitive; the
        // surface only contributes the chrome that is a legitimate per-component
        // design difference (border, radius, shadow).
        public var cardBorder: String
        public var cardRadius: String
        public var cardShadow: String

        public init(
            cardBorder: String,
            cardRadius: String,
            cardShadow: String
        ) {
            self.cardBorder = cardBorder
            self.cardRadius = cardRadius
            self.cardShadow = cardShadow
        }

        public func overriding(_ override: Override) -> Surface {
            Surface(
                cardBorder: override.cardBorder ?? cardBorder,
                cardRadius: override.cardRadius ?? cardRadius,
                cardShadow: override.cardShadow ?? cardShadow
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var cardBorder: String?
            public var cardRadius: String?
            public var cardShadow: String?

            public init(
                cardBorder: String? = nil,
                cardRadius: String? = nil,
                cardShadow: String? = nil
            ) {
                self.cardBorder = cardBorder
                self.cardRadius = cardRadius
                self.cardShadow = cardShadow
            }
        }
    }

    struct Typography: Codable, Sendable, Equatable {
        public var pageHeadingSize: String
        public var pageHeadingLineHeight: String
        public var sectionHeadingSize: String
        public var subsectionHeadingSize: String

        public init(
            pageHeadingSize: String,
            pageHeadingLineHeight: String,
            sectionHeadingSize: String,
            subsectionHeadingSize: String
        ) {
            self.pageHeadingSize = pageHeadingSize
            self.pageHeadingLineHeight = pageHeadingLineHeight
            self.sectionHeadingSize = sectionHeadingSize
            self.subsectionHeadingSize = subsectionHeadingSize
        }

        public func overriding(_ override: Override) -> Typography {
            Typography(
                pageHeadingSize: override.pageHeadingSize ?? pageHeadingSize,
                pageHeadingLineHeight: override.pageHeadingLineHeight ?? pageHeadingLineHeight,
                sectionHeadingSize: override.sectionHeadingSize ?? sectionHeadingSize,
                subsectionHeadingSize: override.subsectionHeadingSize ?? subsectionHeadingSize
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var pageHeadingSize: String?
            public var pageHeadingLineHeight: String?
            public var sectionHeadingSize: String?
            public var subsectionHeadingSize: String?

            public init(
                pageHeadingSize: String? = nil,
                pageHeadingLineHeight: String? = nil,
                sectionHeadingSize: String? = nil,
                subsectionHeadingSize: String? = nil
            ) {
                self.pageHeadingSize = pageHeadingSize
                self.pageHeadingLineHeight = pageHeadingLineHeight
                self.sectionHeadingSize = sectionHeadingSize
                self.subsectionHeadingSize = subsectionHeadingSize
            }
        }
    }

    struct Control: Codable, Sendable, Equatable {
        public var miniHeight: String
        public var smallHeight: String
        public var regularHeight: String
        public var largeHeight: String
        public var disabledOpacity: String

        public init(
            miniHeight: String,
            smallHeight: String,
            regularHeight: String,
            largeHeight: String,
            disabledOpacity: String
        ) {
            self.miniHeight = miniHeight
            self.smallHeight = smallHeight
            self.regularHeight = regularHeight
            self.largeHeight = largeHeight
            self.disabledOpacity = disabledOpacity
        }

        public func overriding(_ override: Override) -> Control {
            Control(
                miniHeight: override.miniHeight ?? miniHeight,
                smallHeight: override.smallHeight ?? smallHeight,
                regularHeight: override.regularHeight ?? regularHeight,
                largeHeight: override.largeHeight ?? largeHeight,
                disabledOpacity: override.disabledOpacity ?? disabledOpacity
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var miniHeight: String?
            public var smallHeight: String?
            public var regularHeight: String?
            public var largeHeight: String?
            public var disabledOpacity: String?

            public init(
                miniHeight: String? = nil,
                smallHeight: String? = nil,
                regularHeight: String? = nil,
                largeHeight: String? = nil,
                disabledOpacity: String? = nil
            ) {
                self.miniHeight = miniHeight
                self.smallHeight = smallHeight
                self.regularHeight = regularHeight
                self.largeHeight = largeHeight
                self.disabledOpacity = disabledOpacity
            }
        }
    }

    struct Button: Codable, Sendable, Equatable {
        public var radius: String
        public var primaryBackground: String
        public var primaryForeground: String
        public var secondaryBackground: String
        public var secondaryForeground: String
        public var secondaryBorder: String
        public var secondaryHoverBackground: String
        public var plainForeground: String

        public init(
            radius: String,
            primaryBackground: String,
            primaryForeground: String,
            secondaryBackground: String,
            secondaryForeground: String,
            secondaryBorder: String,
            secondaryHoverBackground: String,
            plainForeground: String
        ) {
            self.radius = radius
            self.primaryBackground = primaryBackground
            self.primaryForeground = primaryForeground
            self.secondaryBackground = secondaryBackground
            self.secondaryForeground = secondaryForeground
            self.secondaryBorder = secondaryBorder
            self.secondaryHoverBackground = secondaryHoverBackground
            self.plainForeground = plainForeground
        }

        public func overriding(_ override: Override) -> Button {
            Button(
                radius: override.radius ?? radius,
                primaryBackground: override.primaryBackground ?? primaryBackground,
                primaryForeground: override.primaryForeground ?? primaryForeground,
                secondaryBackground: override.secondaryBackground ?? secondaryBackground,
                secondaryForeground: override.secondaryForeground ?? secondaryForeground,
                secondaryBorder: override.secondaryBorder ?? secondaryBorder,
                secondaryHoverBackground: override.secondaryHoverBackground ?? secondaryHoverBackground,
                plainForeground: override.plainForeground ?? plainForeground
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var radius: String?
            public var primaryBackground: String?
            public var primaryForeground: String?
            public var secondaryBackground: String?
            public var secondaryForeground: String?
            public var secondaryBorder: String?
            public var secondaryHoverBackground: String?
            public var plainForeground: String?

            public init(
                radius: String? = nil,
                primaryBackground: String? = nil,
                primaryForeground: String? = nil,
                secondaryBackground: String? = nil,
                secondaryForeground: String? = nil,
                secondaryBorder: String? = nil,
                secondaryHoverBackground: String? = nil,
                plainForeground: String? = nil
            ) {
                self.radius = radius
                self.primaryBackground = primaryBackground
                self.primaryForeground = primaryForeground
                self.secondaryBackground = secondaryBackground
                self.secondaryForeground = secondaryForeground
                self.secondaryBorder = secondaryBorder
                self.secondaryHoverBackground = secondaryHoverBackground
                self.plainForeground = plainForeground
            }
        }
    }

    struct Field: Codable, Sendable, Equatable {
        public var background: String
        public var border: String
        public var radius: String
        public var padding: String
        public var labelSize: String

        public init(background: String, border: String, radius: String, padding: String, labelSize: String) {
            self.background = background
            self.border = border
            self.radius = radius
            self.padding = padding
            self.labelSize = labelSize
        }

        public func overriding(_ override: Override) -> Field {
            Field(
                background: override.background ?? background,
                border: override.border ?? border,
                radius: override.radius ?? radius,
                padding: override.padding ?? padding,
                labelSize: override.labelSize ?? labelSize
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var background: String?
            public var border: String?
            public var radius: String?
            public var padding: String?
            public var labelSize: String?

            public init(
                background: String? = nil,
                border: String? = nil,
                radius: String? = nil,
                padding: String? = nil,
                labelSize: String? = nil
            ) {
                self.background = background
                self.border = border
                self.radius = radius
                self.padding = padding
                self.labelSize = labelSize
            }
        }
    }

    struct Badge: Codable, Sendable, Equatable {
        public var background: String
        public var border: String
        public var foreground: String
        public var radius: String
        public var padding: String

        public init(background: String, border: String, foreground: String, radius: String, padding: String) {
            self.background = background
            self.border = border
            self.foreground = foreground
            self.radius = radius
            self.padding = padding
        }

        public func overriding(_ override: Override) -> Badge {
            Badge(
                background: override.background ?? background,
                border: override.border ?? border,
                foreground: override.foreground ?? foreground,
                radius: override.radius ?? radius,
                padding: override.padding ?? padding
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var background: String?
            public var border: String?
            public var foreground: String?
            public var radius: String?
            public var padding: String?

            public init(
                background: String? = nil,
                border: String? = nil,
                foreground: String? = nil,
                radius: String? = nil,
                padding: String? = nil
            ) {
                self.background = background
                self.border = border
                self.foreground = foreground
                self.radius = radius
                self.padding = padding
            }
        }
    }

    struct ValueDisplay: Codable, Sendable, Equatable {
        public var background: String
        public var border: String
        public var radius: String
        public var padding: String
        public var valueSize: String
        public var valueWeight: String

        public init(
            background: String,
            border: String,
            radius: String,
            padding: String,
            valueSize: String,
            valueWeight: String
        ) {
            self.background = background
            self.border = border
            self.radius = radius
            self.padding = padding
            self.valueSize = valueSize
            self.valueWeight = valueWeight
        }

        public func overriding(_ override: Override) -> ValueDisplay {
            ValueDisplay(
                background: override.background ?? background,
                border: override.border ?? border,
                radius: override.radius ?? radius,
                padding: override.padding ?? padding,
                valueSize: override.valueSize ?? valueSize,
                valueWeight: override.valueWeight ?? valueWeight
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var background: String?
            public var border: String?
            public var radius: String?
            public var padding: String?
            public var valueSize: String?
            public var valueWeight: String?

            public init(
                background: String? = nil,
                border: String? = nil,
                radius: String? = nil,
                padding: String? = nil,
                valueSize: String? = nil,
                valueWeight: String? = nil
            ) {
                self.background = background
                self.border = border
                self.radius = radius
                self.padding = padding
                self.valueSize = valueSize
                self.valueWeight = valueWeight
            }
        }
    }

    struct Navigation: Codable, Sendable, Equatable {
        public var gap: String
        public var linkForeground: String
        public var linkDecoration: String
        public var linkHoverDecoration: String

        public init(gap: String, linkForeground: String, linkDecoration: String, linkHoverDecoration: String) {
            self.gap = gap
            self.linkForeground = linkForeground
            self.linkDecoration = linkDecoration
            self.linkHoverDecoration = linkHoverDecoration
        }

        public func overriding(_ override: Override) -> Navigation {
            Navigation(
                gap: override.gap ?? gap,
                linkForeground: override.linkForeground ?? linkForeground,
                linkDecoration: override.linkDecoration ?? linkDecoration,
                linkHoverDecoration: override.linkHoverDecoration ?? linkHoverDecoration
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var gap: String?
            public var linkForeground: String?
            public var linkDecoration: String?
            public var linkHoverDecoration: String?

            public init(
                gap: String? = nil,
                linkForeground: String? = nil,
                linkDecoration: String? = nil,
                linkHoverDecoration: String? = nil
            ) {
                self.gap = gap
                self.linkForeground = linkForeground
                self.linkDecoration = linkDecoration
                self.linkHoverDecoration = linkHoverDecoration
            }
        }
    }

    struct Toggle: Codable, Sendable, Equatable {
        public var width: String
        public var height: String
        public var thumbSize: String
        public var thumbOffset: String
        public var checkedThumbOffset: String

        public init(width: String, height: String, thumbSize: String, thumbOffset: String, checkedThumbOffset: String) {
            self.width = width
            self.height = height
            self.thumbSize = thumbSize
            self.thumbOffset = thumbOffset
            self.checkedThumbOffset = checkedThumbOffset
        }

        public func overriding(_ override: Override) -> Toggle {
            Toggle(
                width: override.width ?? width,
                height: override.height ?? height,
                thumbSize: override.thumbSize ?? thumbSize,
                thumbOffset: override.thumbOffset ?? thumbOffset,
                checkedThumbOffset: override.checkedThumbOffset ?? checkedThumbOffset
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var width: String?
            public var height: String?
            public var thumbSize: String?
            public var thumbOffset: String?
            public var checkedThumbOffset: String?

            public init(
                width: String? = nil,
                height: String? = nil,
                thumbSize: String? = nil,
                thumbOffset: String? = nil,
                checkedThumbOffset: String? = nil
            ) {
                self.width = width
                self.height = height
                self.thumbSize = thumbSize
                self.thumbOffset = thumbOffset
                self.checkedThumbOffset = checkedThumbOffset
            }
        }
    }

    struct Motion: Codable, Sendable, Equatable {
        public var quick: String
        public var standard: String

        public init(quick: String, standard: String) {
            self.quick = quick
            self.standard = standard
        }

        public func overriding(_ override: Override) -> Motion {
            Motion(
                quick: override.quick ?? quick,
                standard: override.standard ?? standard
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var quick: String?
            public var standard: String?

            public init(quick: String? = nil, standard: String? = nil) {
                self.quick = quick
                self.standard = standard
            }
        }
    }

    /// The single set of knobs the shared `swui-material`/`swui-glass` recipe
    /// reads. A design style sets these once; every chrome component composes a
    /// material *level* (ultra-thin … bar) and the CSS derives that level's fill
    /// opacity from `opacity` ± N·`opacityStep`. Solid styles set `opacity` to 1
    /// and `opacityStep`/`blur`/`refraction` to their no-op values, so the same
    /// component code reads as a plain surface; glass styles enable blur, rim and
    /// SVG refraction. `solidFill` is the opaque fallback used where
    /// `backdrop-filter` is unsupported or reduced-transparency is requested.
    struct Material: Codable, Sendable, Equatable {
        public var tint: String
        public var opacity: String
        public var opacityStep: String
        public var blur: String
        public var saturate: String
        public var brightness: String
        public var rim: String
        public var refraction: String
        public var solidFill: String

        public init(
            tint: String,
            opacity: String,
            opacityStep: String,
            blur: String,
            saturate: String,
            brightness: String,
            rim: String,
            refraction: String,
            solidFill: String
        ) {
            self.tint = tint
            self.opacity = opacity
            self.opacityStep = opacityStep
            self.blur = blur
            self.saturate = saturate
            self.brightness = brightness
            self.rim = rim
            self.refraction = refraction
            self.solidFill = solidFill
        }

        public func overriding(_ override: Override) -> Material {
            Material(
                tint: override.tint ?? tint,
                opacity: override.opacity ?? opacity,
                opacityStep: override.opacityStep ?? opacityStep,
                blur: override.blur ?? blur,
                saturate: override.saturate ?? saturate,
                brightness: override.brightness ?? brightness,
                rim: override.rim ?? rim,
                refraction: override.refraction ?? refraction,
                solidFill: override.solidFill ?? solidFill
            )
        }

        public struct Override: Codable, Sendable, Equatable {
            public var tint: String?
            public var opacity: String?
            public var opacityStep: String?
            public var blur: String?
            public var saturate: String?
            public var brightness: String?
            public var rim: String?
            public var refraction: String?
            public var solidFill: String?

            public init(
                tint: String? = nil,
                opacity: String? = nil,
                opacityStep: String? = nil,
                blur: String? = nil,
                saturate: String? = nil,
                brightness: String? = nil,
                rim: String? = nil,
                refraction: String? = nil,
                solidFill: String? = nil
            ) {
                self.tint = tint
                self.opacity = opacity
                self.opacityStep = opacityStep
                self.blur = blur
                self.saturate = saturate
                self.brightness = brightness
                self.rim = rim
                self.refraction = refraction
                self.solidFill = solidFill
            }
        }
    }
}

public extension StyleSystem {
    static let `default` = StyleSystem(
        id: "swift-web",
        root: Root(
            pageInlinePadding: "clamp(16px, 4vw, 24px)",
            stackSpacing: "var(--swui-space-md)"
        ),
        layout: Layout(
            lazyIntrinsicSize: "auto 56px"
        ),
        surface: Surface(
            cardBorder: "1px solid var(--swui-border)",
            cardRadius: "var(--swui-radius-medium)",
            cardShadow: "0 1px 2px rgba(15, 23, 42, 0.05)"
        ),
        typography: Typography(
            pageHeadingSize: "clamp(32px, 5vw, 44px)",
            pageHeadingLineHeight: "1",
            sectionHeadingSize: "20px",
            subsectionHeadingSize: "16px"
        ),
        control: Control(
            miniHeight: "28px",
            smallHeight: "32px",
            regularHeight: "36px",
            largeHeight: "44px",
            disabledOpacity: "0.55"
        ),
        button: Button(
            radius: "var(--swui-radius-medium)",
            // Design-style default background; the control tint override is applied
            // at the `.swui-button-primary` rule via var(--swui-control-tint, ...) so
            // that the inline per-button tint resolves on the button element itself.
            primaryBackground: "var(--swui-accent)",
            primaryForeground: "var(--swui-accent-text)",
            secondaryBackground: "var(--swui-surface-raised)",
            secondaryForeground: "var(--swui-text)",
            secondaryBorder: "var(--swui-border)",
            secondaryHoverBackground: "color-mix(in srgb, var(--swui-surface-raised) 82%, var(--swui-border))",
            plainForeground: "var(--swui-accent)"
        ),
        field: Field(
            background: "var(--swui-surface-raised)",
            border: "1px solid var(--swui-border)",
            radius: "var(--swui-radius-small)",
            padding: "6px 8px",
            labelSize: "13px"
        ),
        badge: Badge(
            background: "var(--swui-surface-raised)",
            border: "1px solid var(--swui-border)",
            foreground: "var(--swui-text-muted)",
            radius: "var(--swui-radius-pill)",
            padding: "2px var(--swui-space-sm)"
        ),
        valueDisplay: ValueDisplay(
            background: "color-mix(in srgb, var(--swui-accent) 9%, var(--swui-surface))",
            border: "1px solid color-mix(in srgb, var(--swui-accent) 28%, var(--swui-border))",
            radius: "var(--swui-radius-medium)",
            padding: "var(--swui-space-lg)",
            valueSize: "44px",
            valueWeight: "700"
        ),
        navigation: Navigation(
            gap: "var(--swui-space-md)",
            linkForeground: "var(--swui-accent)",
            linkDecoration: "none",
            linkHoverDecoration: "underline"
        ),
        toggle: Toggle(
            width: "34px",
            height: "20px",
            thumbSize: "14px",
            thumbOffset: "2px",
            checkedThumbOffset: "14px"
        ),
        motion: Motion(
            quick: "120ms ease",
            standard: "180ms ease"
        ),
        // Solid base: every level renders as the opaque theme surface. A zero
        // opacity step collapses the levels onto one fill, no backdrop blur, and
        // no SVG refraction; depth comes from the components' own borders and
        // shadows. Components may still override `--swui-material-tint` inline to
        // keep semantic surfaces (e.g. a raised field) distinct.
        material: Material(
            tint: "var(--swui-surface)",
            opacity: "1",
            opacityStep: "0",
            blur: "0px",
            saturate: "1",
            brightness: "1",
            rim: "none",
            refraction: "none",
            solidFill: "var(--swui-surface)"
        )
    )

    static let swiftWeb = StyleSystem.default

    static let material = StyleSystem(id: "material") {
        .root {
            .pageInlinePadding("clamp(16px, 5vw, 32px)")
        }
        .surface {
            .cardRadius("12px")
            .cardShadow("0 1px 3px rgba(0, 0, 0, 0.12), 0 1px 2px rgba(0, 0, 0, 0.08)")
        }
        .control {
            .regularHeight("40px")
            .largeHeight("48px")
        }
        .button {
            .radius("20px")
            .secondaryBackground("color-mix(in srgb, var(--swui-surface-raised) 88%, var(--swui-accent))")
            .secondaryHoverBackground("color-mix(in srgb, var(--swui-surface-raised) 78%, var(--swui-accent))")
        }
        .field {
            .radius("8px")
            .padding("8px 12px")
        }
        .motion {
            .quick("150ms cubic-bezier(0.2, 0, 0, 1)")
        }
    }

    static let liquidGlass = StyleSystem(id: "liquid-glass") {
        .root {
            .pageInlinePadding("clamp(18px, 5vw, 36px)")
        }
        .surface {
            // Card fill + backdrop now come from the shared material primitive
            // (Card composes `.regularMaterial`); the surface only keeps the
            // glassy rim border, larger radius, and elevated drop shadow.
            .cardBorder("1px solid color-mix(in srgb, #ffffff 34%, var(--swui-border))")
            .cardRadius("22px")
            .cardShadow("0 18px 48px rgba(15, 23, 42, 0.18)")
        }
        .control {
            .regularHeight("40px")
            .largeHeight("48px")
            .disabledOpacity("0.62")
        }
        .button {
            // The secondary surface fill + translucency now come from the shared
            // material primitive (the bordered button composes `.thinMaterial`).
            // Only the glassy rim border stays a per-button difference; the tint
            // hues stay opaque so the material owns the translucency.
            .radius("999px")
            .secondaryBorder("color-mix(in srgb, var(--swui-border) 58%, transparent)")
        }
        .badge {
            // Fill + translucency come from the shared material; only the glassy
            // rim border is overridden here.
            .border("1px solid color-mix(in srgb, var(--swui-border) 54%, transparent)")
        }
        .valueDisplay {
            // Fill + translucency come from the shared material; the accent-tinted
            // rim border and larger radius stay a per-component difference.
            .border("1px solid color-mix(in srgb, var(--swui-accent) 24%, transparent)")
            .radius("20px")
        }
        .motion {
            .quick("160ms cubic-bezier(0.16, 1, 0.3, 1)")
            .standard("240ms cubic-bezier(0.16, 1, 0.3, 1)")
        }
        .material {
            // Real Liquid Glass: translucent surface tint scaled per level, a
            // wide backdrop blur with boosted saturation, a specular rim, and the
            // SVG displacement refraction. `solidFill` is the opaque fallback for
            // browsers without `backdrop-filter` and for reduced-transparency.
            .tint("var(--swui-surface)")
            .opacity("0.62")
            .opacityStep("0.07")
            .blur("24px")
            .saturate("1.6")
            .brightness("1.05")
            .rim("inset 0 1px 0 0 color-mix(in srgb, #ffffff 70%, transparent), inset 0 -1px 1px 0 color-mix(in srgb, #000000 12%, transparent)")
            .refraction("url(\"#swui-glass-refraction\")")
            .solidFill("color-mix(in srgb, var(--swui-surface) 88%, var(--swui-border))")
        }
    }
}

public extension StyleSystem {
    var cssVariableStyle: Style {
        Style {
            .custom("--swui-page-inline-padding", root.pageInlinePadding)
            .custom("--swui-stack-spacing", root.stackSpacing)
            .custom("--swui-lazy-intrinsic-size", layout.lazyIntrinsicSize)
            .custom("--swui-card-border", surface.cardBorder)
            .custom("--swui-card-radius", surface.cardRadius)
            .custom("--swui-card-shadow", surface.cardShadow)
            .custom("--swui-heading-page-size", typography.pageHeadingSize)
            .custom("--swui-heading-page-line-height", typography.pageHeadingLineHeight)
            .custom("--swui-heading-section-size", typography.sectionHeadingSize)
            .custom("--swui-heading-subsection-size", typography.subsectionHeadingSize)
            .custom("--swui-control-mini-height", control.miniHeight)
            .custom("--swui-control-small-height", control.smallHeight)
            .custom("--swui-control-regular-height", control.regularHeight)
            .custom("--swui-control-large-height", control.largeHeight)
            .custom("--swui-control-disabled-opacity", control.disabledOpacity)
            .custom("--swui-button-radius", button.radius)
            .custom("--swui-button-primary-background", button.primaryBackground)
            .custom("--swui-button-primary-foreground", button.primaryForeground)
            .custom("--swui-button-secondary-background", button.secondaryBackground)
            .custom("--swui-button-secondary-foreground", button.secondaryForeground)
            .custom("--swui-button-secondary-border", button.secondaryBorder)
            .custom("--swui-button-secondary-hover-background", button.secondaryHoverBackground)
            .custom("--swui-button-plain-foreground", button.plainForeground)
            .custom("--swui-field-background", field.background)
            .custom("--swui-field-border", field.border)
            .custom("--swui-field-radius", field.radius)
            .custom("--swui-field-padding", field.padding)
            .custom("--swui-field-label-size", field.labelSize)
            .custom("--swui-badge-background", badge.background)
            .custom("--swui-badge-border", badge.border)
            .custom("--swui-badge-foreground", badge.foreground)
            .custom("--swui-badge-radius", badge.radius)
            .custom("--swui-badge-padding", badge.padding)
            .custom("--swui-value-display-background", valueDisplay.background)
            .custom("--swui-value-display-border", valueDisplay.border)
            .custom("--swui-value-display-radius", valueDisplay.radius)
            .custom("--swui-value-display-padding", valueDisplay.padding)
            .custom("--swui-value-size", valueDisplay.valueSize)
            .custom("--swui-value-weight", valueDisplay.valueWeight)
            .custom("--swui-navigation-gap", navigation.gap)
            .custom("--swui-navigation-link-foreground", navigation.linkForeground)
            .custom("--swui-navigation-link-decoration", navigation.linkDecoration)
            .custom("--swui-navigation-link-hover-decoration", navigation.linkHoverDecoration)
            .custom("--swui-toggle-width", toggle.width)
            .custom("--swui-toggle-height", toggle.height)
            .custom("--swui-toggle-thumb-size", toggle.thumbSize)
            .custom("--swui-toggle-thumb-offset", toggle.thumbOffset)
            .custom("--swui-toggle-checked-thumb-offset", toggle.checkedThumbOffset)
            .custom("--swui-motion-quick", motion.quick)
            .custom("--swui-motion-standard", motion.standard)
            .custom("--swui-material-tint", material.tint)
            .custom("--swui-material-opacity", material.opacity)
            .custom("--swui-material-opacity-step", material.opacityStep)
            .custom("--swui-material-blur", material.blur)
            .custom("--swui-material-saturate", material.saturate)
            .custom("--swui-material-brightness", material.brightness)
            .custom("--swui-material-rim", material.rim)
            .custom("--swui-material-refraction", material.refraction)
            .custom("--swui-material-solid-fill", material.solidFill)
        }
    }
}
