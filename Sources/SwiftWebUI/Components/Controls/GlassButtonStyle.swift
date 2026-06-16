import SwiftHTML

/// A button styled as Liquid Glass (SwiftUI's `.glass`).
///
/// The button surface is the shared `swui-glass` recipe: a translucent fill,
/// backdrop blur, specular rim, and SVG refraction, plus the interactive
/// pointer highlight. Under a solid design style the glass recipe collapses to
/// an opaque surface, so the same button reads as a plain raised control.
public struct GlassButtonStyle: ButtonStyle {
    public init() {}

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
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
            style: .custom("--swui-control-tint", configuration.tint)
        )
    }
}
