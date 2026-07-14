import SwiftWebUITheme
public enum ButtonStyleKind: String, Sendable, Equatable {
    case automatic
    case bordered
    case borderedProminent
    case glass
    case glassProminent
    case plain

    func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        switch self {
        case .automatic:
            switch configuration.prominence {
            case .primary:
                Self.borderedProminent.resolve(configuration: configuration, context: context)
            case .secondary:
                Self.bordered.resolve(configuration: configuration, context: context)
            }
        case .bordered:
            ButtonStyleResult(
                classNames: [
                    "swui-button",
                    "swui-button-secondary",
                    MaterialClass.material,
                    MaterialClass.thin,
                    configuration.controlSize.className,
                    configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
                ],
                style: controlTintStyle(configuration.tint)
            )
        case .borderedProminent:
            ButtonStyleResult(
                classNames: [
                    "swui-button",
                    "swui-button-primary",
                    configuration.controlSize.className,
                    configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
                ],
                style: controlTintStyle(configuration.tint)
            )
        case .glass:
            ButtonStyleResult(
                classNames: [
                    "swui-button",
                    "swui-button-glass",
                    MaterialClass.glass,
                    MaterialClass.regular,
                    MaterialClass.interactive,
                    configuration.controlSize.className,
                    configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
                ],
                style: controlTintStyle(configuration.tint)
            )
        case .glassProminent:
            ButtonStyleResult(
                classNames: [
                    "swui-button",
                    "swui-button-glass-prominent",
                    MaterialClass.glass,
                    MaterialClass.regular,
                    MaterialClass.interactive,
                    configuration.controlSize.className,
                    configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
                ],
                style: controlTintStyle(configuration.tint)
            )
        case .plain:
            ButtonStyleResult(
                classNames: [
                    "swui-button",
                    "swui-button-plain",
                    configuration.controlSize.className,
                    configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
                ],
                style: controlTintStyle(configuration.tint)
            )
        }
    }
}

#if !hasFeature(Embedded)
extension ButtonStyleKind: Codable {}
#endif
