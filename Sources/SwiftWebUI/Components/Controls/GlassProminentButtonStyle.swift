import SwiftHTML

/// A prominent Liquid Glass button (SwiftUI's `.glassProminent`).
///
/// Like `GlassButtonStyle`, the surface is the shared `swui-glass` recipe, but
/// the glass is washed with the control tint (the accent by default) so the
/// button reads as the prominent call to action. The `.swui-button-glass-prominent`
/// rule feeds the tint into the material and sets the accent-on-glass text color.
public struct GlassProminentButtonStyle: ButtonStyle {
    public init() {}

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
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
            style: .custom("--swui-control-tint", configuration.tint)
        )
    }
}
