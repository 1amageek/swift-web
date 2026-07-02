import SwiftHTML

public struct StyleSystem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    var root: Root
    var layout: Layout
    var surface: Surface
    var typography: Typography
    var control: Control
    var button: Button
    var field: Field
    var badge: Badge
    var navigation: Navigation
    var toggle: Toggle
    var motion: Motion
    var material: Material

    init(
        id: String,
        root: Root,
        layout: Layout,
        surface: Surface,
        typography: Typography,
        control: Control,
        button: Button,
        field: Field,
        badge: Badge,
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
        self.navigation = navigation
        self.toggle = toggle
        self.motion = motion
        self.material = material
    }

    func overriding(_ override: Override) -> StyleSystem {
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

extension StyleSystem {
    struct Override: Codable, Sendable, Equatable {
        var id: String?
        var root: Root.Override?
        var layout: Layout.Override?
        var surface: Surface.Override?
        var typography: Typography.Override?
        var control: Control.Override?
        var button: Button.Override?
        var field: Field.Override?
        var badge: Badge.Override?
        var navigation: Navigation.Override?
        var toggle: Toggle.Override?
        var motion: Motion.Override?
        var material: Material.Override?

        init(
            id: String? = nil,
            root: Root.Override? = nil,
            layout: Layout.Override? = nil,
            surface: Surface.Override? = nil,
            typography: Typography.Override? = nil,
            control: Control.Override? = nil,
            button: Button.Override? = nil,
            field: Field.Override? = nil,
            badge: Badge.Override? = nil,
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
            self.navigation = navigation
            self.toggle = toggle
            self.motion = motion
            self.material = material
        }
    }

    struct Root: Codable, Sendable, Equatable {
        var pageInlinePadding: String
        var stackSpacing: String

        init(pageInlinePadding: String, stackSpacing: String) {
            self.pageInlinePadding = pageInlinePadding
            self.stackSpacing = stackSpacing
        }

        func overriding(_ override: Override) -> Root {
            Root(
                pageInlinePadding: override.pageInlinePadding ?? pageInlinePadding,
                stackSpacing: override.stackSpacing ?? stackSpacing
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var pageInlinePadding: String?
            var stackSpacing: String?

            init(pageInlinePadding: String? = nil, stackSpacing: String? = nil) {
                self.pageInlinePadding = pageInlinePadding
                self.stackSpacing = stackSpacing
            }
        }
    }

    struct Layout: Codable, Sendable, Equatable {
        var lazyIntrinsicSize: String

        init(lazyIntrinsicSize: String) {
            self.lazyIntrinsicSize = lazyIntrinsicSize
        }

        func overriding(_ override: Override) -> Layout {
            Layout(
                lazyIntrinsicSize: override.lazyIntrinsicSize ?? lazyIntrinsicSize
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var lazyIntrinsicSize: String?

            init(lazyIntrinsicSize: String? = nil) {
                self.lazyIntrinsicSize = lazyIntrinsicSize
            }
        }
    }

    struct Surface: Codable, Sendable, Equatable {
        var containerBorder: String
        var containerRadius: String
        var containerShadow: String

        init(
            containerBorder: String,
            containerRadius: String,
            containerShadow: String
        ) {
            self.containerBorder = containerBorder
            self.containerRadius = containerRadius
            self.containerShadow = containerShadow
        }

        func overriding(_ override: Override) -> Surface {
            Surface(
                containerBorder: override.containerBorder ?? containerBorder,
                containerRadius: override.containerRadius ?? containerRadius,
                containerShadow: override.containerShadow ?? containerShadow
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var containerBorder: String?
            var containerRadius: String?
            var containerShadow: String?

            init(
                containerBorder: String? = nil,
                containerRadius: String? = nil,
                containerShadow: String? = nil
            ) {
                self.containerBorder = containerBorder
                self.containerRadius = containerRadius
                self.containerShadow = containerShadow
            }
        }
    }

    struct Typography: Codable, Sendable, Equatable {
        var pageHeadingSize: String
        var pageHeadingLineHeight: String
        var sectionHeadingSize: String
        var subsectionHeadingSize: String

        init(
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

        func overriding(_ override: Override) -> Typography {
            Typography(
                pageHeadingSize: override.pageHeadingSize ?? pageHeadingSize,
                pageHeadingLineHeight: override.pageHeadingLineHeight ?? pageHeadingLineHeight,
                sectionHeadingSize: override.sectionHeadingSize ?? sectionHeadingSize,
                subsectionHeadingSize: override.subsectionHeadingSize ?? subsectionHeadingSize
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var pageHeadingSize: String?
            var pageHeadingLineHeight: String?
            var sectionHeadingSize: String?
            var subsectionHeadingSize: String?

            init(
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
        var miniHeight: String
        var smallHeight: String
        var regularHeight: String
        var largeHeight: String
        var extraLargeHeight: String
        var disabledOpacity: String

        init(
            miniHeight: String,
            smallHeight: String,
            regularHeight: String,
            largeHeight: String,
            extraLargeHeight: String,
            disabledOpacity: String
        ) {
            self.miniHeight = miniHeight
            self.smallHeight = smallHeight
            self.regularHeight = regularHeight
            self.largeHeight = largeHeight
            self.extraLargeHeight = extraLargeHeight
            self.disabledOpacity = disabledOpacity
        }

        func overriding(_ override: Override) -> Control {
            Control(
                miniHeight: override.miniHeight ?? miniHeight,
                smallHeight: override.smallHeight ?? smallHeight,
                regularHeight: override.regularHeight ?? regularHeight,
                largeHeight: override.largeHeight ?? largeHeight,
                extraLargeHeight: override.extraLargeHeight ?? extraLargeHeight,
                disabledOpacity: override.disabledOpacity ?? disabledOpacity
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var miniHeight: String?
            var smallHeight: String?
            var regularHeight: String?
            var largeHeight: String?
            var extraLargeHeight: String?
            var disabledOpacity: String?

            init(
                miniHeight: String? = nil,
                smallHeight: String? = nil,
                regularHeight: String? = nil,
                largeHeight: String? = nil,
                extraLargeHeight: String? = nil,
                disabledOpacity: String? = nil
            ) {
                self.miniHeight = miniHeight
                self.smallHeight = smallHeight
                self.regularHeight = regularHeight
                self.largeHeight = largeHeight
                self.extraLargeHeight = extraLargeHeight
                self.disabledOpacity = disabledOpacity
            }
        }
    }

    struct Button: Codable, Sendable, Equatable {
        var radius: String
        var primaryBackground: String
        var primaryForeground: String
        var secondaryBackground: String
        var secondaryForeground: String
        var secondaryBorder: String
        var secondaryHoverBackground: String
        var plainForeground: String

        init(
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

        func overriding(_ override: Override) -> Button {
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

        struct Override: Codable, Sendable, Equatable {
            var radius: String?
            var primaryBackground: String?
            var primaryForeground: String?
            var secondaryBackground: String?
            var secondaryForeground: String?
            var secondaryBorder: String?
            var secondaryHoverBackground: String?
            var plainForeground: String?

            init(
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
        var background: String
        var border: String
        var radius: String
        var padding: String
        var labelSize: String

        init(background: String, border: String, radius: String, padding: String, labelSize: String) {
            self.background = background
            self.border = border
            self.radius = radius
            self.padding = padding
            self.labelSize = labelSize
        }

        func overriding(_ override: Override) -> Field {
            Field(
                background: override.background ?? background,
                border: override.border ?? border,
                radius: override.radius ?? radius,
                padding: override.padding ?? padding,
                labelSize: override.labelSize ?? labelSize
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var background: String?
            var border: String?
            var radius: String?
            var padding: String?
            var labelSize: String?

            init(
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
        var background: String
        var border: String
        var foreground: String
        var radius: String
        var padding: String

        init(background: String, border: String, foreground: String, radius: String, padding: String) {
            self.background = background
            self.border = border
            self.foreground = foreground
            self.radius = radius
            self.padding = padding
        }

        func overriding(_ override: Override) -> Badge {
            Badge(
                background: override.background ?? background,
                border: override.border ?? border,
                foreground: override.foreground ?? foreground,
                radius: override.radius ?? radius,
                padding: override.padding ?? padding
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var background: String?
            var border: String?
            var foreground: String?
            var radius: String?
            var padding: String?

            init(
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

    struct Navigation: Codable, Sendable, Equatable {
        var gap: String
        var linkForeground: String
        var linkDecoration: String
        var linkHoverDecoration: String

        init(gap: String, linkForeground: String, linkDecoration: String, linkHoverDecoration: String) {
            self.gap = gap
            self.linkForeground = linkForeground
            self.linkDecoration = linkDecoration
            self.linkHoverDecoration = linkHoverDecoration
        }

        func overriding(_ override: Override) -> Navigation {
            Navigation(
                gap: override.gap ?? gap,
                linkForeground: override.linkForeground ?? linkForeground,
                linkDecoration: override.linkDecoration ?? linkDecoration,
                linkHoverDecoration: override.linkHoverDecoration ?? linkHoverDecoration
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var gap: String?
            var linkForeground: String?
            var linkDecoration: String?
            var linkHoverDecoration: String?

            init(
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
        var width: String
        var height: String
        var thumbSize: String
        var thumbOffset: String
        var checkedThumbOffset: String

        init(width: String, height: String, thumbSize: String, thumbOffset: String, checkedThumbOffset: String) {
            self.width = width
            self.height = height
            self.thumbSize = thumbSize
            self.thumbOffset = thumbOffset
            self.checkedThumbOffset = checkedThumbOffset
        }

        func overriding(_ override: Override) -> Toggle {
            Toggle(
                width: override.width ?? width,
                height: override.height ?? height,
                thumbSize: override.thumbSize ?? thumbSize,
                thumbOffset: override.thumbOffset ?? thumbOffset,
                checkedThumbOffset: override.checkedThumbOffset ?? checkedThumbOffset
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var width: String?
            var height: String?
            var thumbSize: String?
            var thumbOffset: String?
            var checkedThumbOffset: String?

            init(
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
        var quick: String
        var standard: String

        init(quick: String, standard: String) {
            self.quick = quick
            self.standard = standard
        }

        func overriding(_ override: Override) -> Motion {
            Motion(
                quick: override.quick ?? quick,
                standard: override.standard ?? standard
            )
        }

        struct Override: Codable, Sendable, Equatable {
            var quick: String?
            var standard: String?

            init(quick: String? = nil, standard: String? = nil) {
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
        var tint: String
        var opacity: String
        var opacityStep: String
        var blur: String
        var saturate: String
        var brightness: String
        var rim: String
        var refraction: String
        var solidFill: String

        init(
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

        func overriding(_ override: Override) -> Material {
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

        struct Override: Codable, Sendable, Equatable {
            var tint: String?
            var opacity: String?
            var opacityStep: String?
            var blur: String?
            var saturate: String?
            var brightness: String?
            var rim: String?
            var refraction: String?
            var solidFill: String?

            init(
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
            containerBorder: "1px solid var(--swui-border)",
            containerRadius: "14px",
            containerShadow: "none"
        ),
        typography: Typography(
            pageHeadingSize: "30px",
            pageHeadingLineHeight: "1.2",
            sectionHeadingSize: "22px",
            subsectionHeadingSize: "17px"
        ),
        control: Control(
            miniHeight: "28px",
            smallHeight: "32px",
            regularHeight: "36px",
            largeHeight: "44px",
            extraLargeHeight: "52px",
            disabledOpacity: "0.55"
        ),
        button: Button(
            radius: "var(--swui-radius-medium)",
            // Design-style default background; the control tint override is applied
            // at the `.swui-button-primary` rule via var(--swui-control-tint, ...) so
            // that the per-button tint resolves on the button element itself.
            primaryBackground: "var(--swui-accent)",
            primaryForeground: "var(--swui-accent-text)",
            secondaryBackground: "var(--swui-surface-raised)",
            secondaryForeground: "var(--swui-text)",
            secondaryBorder: "var(--swui-border)",
            secondaryHoverBackground: "color-mix(in srgb, var(--swui-surface-raised) 82%, var(--swui-border))",
            plainForeground: "var(--swui-accent)"
        ),
        field: Field(
            background: "var(--swui-surface)",
            border: "1px solid var(--swui-border)",
            radius: "var(--swui-radius-medium)",
            padding: "7px 11px",
            labelSize: "12.5px"
        ),
        badge: Badge(
            background: "color-mix(in srgb, var(--swui-control-tint, var(--swui-accent)) 13%, var(--swui-surface))",
            border: "1px solid color-mix(in srgb, var(--swui-control-tint, var(--swui-accent)) 26%, transparent)",
            foreground: "var(--swui-control-tint, var(--swui-accent))",
            radius: "var(--swui-radius-pill)",
            padding: "3px 10px"
        ),
        navigation: Navigation(
            gap: "var(--swui-space-md)",
            linkForeground: "var(--swui-accent)",
            linkDecoration: "none",
            linkHoverDecoration: "underline"
        ),
        toggle: Toggle(
            width: "38px",
            height: "23px",
            thumbSize: "19px",
            // 1px inside the 1px track border centers the 19px thumb in the
            // 21px content box on both axes; the checked offset slides it the
            // full travel to a symmetric 1px gap on the trailing edge.
            thumbOffset: "1px",
            checkedThumbOffset: "15px"
        ),
        motion: Motion(
            quick: "120ms ease",
            standard: "180ms ease"
        ),
        // Solid base: every level renders as the opaque root surface. A zero
        // opacity step collapses the levels onto one fill, no backdrop blur, and
        // no SVG refraction; depth comes from the components' own borders and
        // shadows. Components may still override `--swui-material-tint` locally to
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
            .pageInlinePadding(.clamp(min: 16, ideal: .vw(5), max: 32))
        }
        .surface {
            .containerRadius(12)
            .containerShadow(.layers([
                .drop(y: 1, blur: 3, color: Color.black.opacity(0.12)),
                .drop(y: 1, blur: 2, color: Color.black.opacity(0.08)),
            ]))
        }
        .control {
            .regularHeight(40)
            .largeHeight(48)
        }
        .button {
            .radius(20)
            .secondaryBackground(Color.surfaceRaised.mix(with: .accent, by: 0.12))
            .secondaryHoverBackground(Color.surfaceRaised.mix(with: .accent, by: 0.22))
        }
        .field {
            .radius(8)
            .padding(vertical: 8, horizontal: 12)
        }
        .motion {
            .quick(.init(milliseconds: 150, curve: .cubicBezier(0.2, 0, 0, 1)))
        }
    }

    static let liquidGlass = StyleSystem(id: "liquid-glass") {
        .root {
            .pageInlinePadding(.clamp(min: 18, ideal: .vw(5), max: 36))
        }
        .surface {
            .containerBorder(.solid(width: 1, color: Color.white.mix(with: .border, by: 0.66)))
            .containerRadius(22)
            .containerShadow(.drop(y: 18, blur: 48, color: Color(hex: 0x0F172A).opacity(0.18)))
        }
        .control {
            .regularHeight(40)
            .largeHeight(48)
            .disabledOpacity(0.62)
        }
        .button {
            // The secondary surface fill + translucency now come from the shared
            // material primitive (the bordered button composes `.thinMaterial`).
            // Only the glassy rim border stays a per-button difference; the tint
            // hues stay opaque so the material owns the translucency.
            .radius(999)
            .secondaryBorder(Color.border.opacity(0.58))
        }
        .badge {
            // Fill + translucency come from the shared material; only the glassy
            // rim border is overridden here.
            .border(.solid(width: 1, color: Color.border.opacity(0.54)))
        }
        .motion {
            .quick(.init(milliseconds: 160, curve: .cubicBezier(0.16, 1, 0.3, 1)))
            .standard(.init(milliseconds: 240, curve: .cubicBezier(0.16, 1, 0.3, 1)))
        }
        .material {
            // Real Liquid Glass: a translucent surface tint scaled per level and
            // a faint backdrop blur with boosted saturation. The refraction and
            // specular highlight are generated per element by the client script,
            // not configured here. `solidFill` is the opaque fallback for browsers
            // without `backdrop-filter` and for reduced-transparency.
            .tint(.surface)
            .opacity(0.62)
            .opacityStep(0.07)
            .blur(24)
            .saturate(1.6)
            .brightness(1.05)
            .solidFill(Color.surface.mix(with: .border, by: 0.12))
        }
    }
}

public extension StyleSystem {
    var cssVariableStyle: Style {
        Style {
            .custom("--swui-page-inline-padding", root.pageInlinePadding)
            .custom("--swui-stack-spacing", root.stackSpacing)
            .custom("--swui-lazy-intrinsic-size", layout.lazyIntrinsicSize)
            .custom("--swui-container-border", surface.containerBorder)
            .custom("--swui-container-radius", surface.containerRadius)
            .custom("--swui-container-shadow", surface.containerShadow)
            .custom("--swui-heading-page-size", typography.pageHeadingSize)
            .custom("--swui-heading-page-line-height", typography.pageHeadingLineHeight)
            .custom("--swui-heading-section-size", typography.sectionHeadingSize)
            .custom("--swui-heading-subsection-size", typography.subsectionHeadingSize)
            .custom("--swui-control-mini-height", control.miniHeight)
            .custom("--swui-control-small-height", control.smallHeight)
            .custom("--swui-control-regular-height", control.regularHeight)
            .custom("--swui-control-large-height", control.largeHeight)
            .custom("--swui-control-extra-large-height", control.extraLargeHeight)
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
