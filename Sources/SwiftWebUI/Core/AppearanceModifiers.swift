import SwiftHTML

public enum BlendMode: Sendable, Equatable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity

    var cssValue: String {
        switch self {
        case .normal:
            "normal"
        case .multiply:
            "multiply"
        case .screen:
            "screen"
        case .overlay:
            "overlay"
        case .darken:
            "darken"
        case .lighten:
            "lighten"
        case .colorDodge:
            "color-dodge"
        case .colorBurn:
            "color-burn"
        case .softLight:
            "soft-light"
        case .hardLight:
            "hard-light"
        case .difference:
            "difference"
        case .exclusion:
            "exclusion"
        case .hue:
            "hue"
        case .saturation:
            "saturation"
        case .color:
            "color"
        case .luminosity:
            "luminosity"
        }
    }
}

public extension HTML {
    func clipped(antialiased: Bool = false) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.overflow("hidden"))]))
    }

    func blur(
        radius: Length,
        opaque: Bool = false
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("blur(\(radius.cssValue))"))
        ]))
    }

    func brightness(_ amount: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("brightness(\(trimmedNumber(1 + amount)))"))
        ]))
    }

    func contrast(_ amount: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("contrast(\(trimmedNumber(amount)))"))
        ]))
    }

    func saturation(_ amount: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("saturate(\(trimmedNumber(amount)))"))
        ]))
    }

    func grayscale(_ amount: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("grayscale(\(trimmedNumber(amount)))"))
        ]))
    }

    func hueRotation(_ angle: Angle) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("hue-rotate(\(angle.cssValue))"))
        ]))
    }

    func colorInvert() -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.filter("invert(1)"))
        ]))
    }

    func colorMultiply(_ color: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .backgroundColor(color)
                .backgroundBlendMode("multiply")
            })
        ]))
    }

    func blendMode(_ blendMode: BlendMode) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.mixBlendMode(blendMode.cssValue))
        ]))
    }

    func rotationEffect(
        _ angle: Angle,
        anchor: UnitPoint = .center
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .transform("rotate(\(angle.cssValue))")
                .transformOrigin(anchor.cssValue)
            })
        ]))
    }

    func scaleEffect(
        _ scale: Double,
        anchor: UnitPoint = .center
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        scaleEffect(x: scale, y: scale, anchor: anchor)
    }

    func scaleEffect(
        x: Double = 1,
        y: Double = 1,
        anchor: UnitPoint = .center
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .transform("scale(\(trimmedNumber(x)), \(trimmedNumber(y)))")
                .transformOrigin(anchor.cssValue)
            })
        ]))
    }

    func allowsHitTesting(_ enabled: Bool) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.pointerEvents(enabled ? "auto" : "none")),
            .aria("disabled", enabled ? "false" : "true"),
        ], role: .semantic))
    }

    func compositingGroup() -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.isolation("isolate"))
        ]))
    }

    func drawingGroup(
        opaque: Bool = false,
        colorMode: ColorRenderingMode = .nonLinear
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("drawing-group", colorMode.cssName),
            styleAttribute(Style {
                .isolation("isolate")
                .backfaceVisibility("hidden")
            }),
        ]))
    }
}

public enum ColorRenderingMode: Sendable, Equatable {
    case nonLinear
    case linear
    case extendedLinear

    var cssName: String {
        switch self {
        case .nonLinear:
            "non-linear"
        case .linear:
            "linear"
        case .extendedLinear:
            "extended-linear"
        }
    }
}
