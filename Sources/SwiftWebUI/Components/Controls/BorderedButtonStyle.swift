import SwiftHTML

public struct BorderedButtonStyle: ButtonStyle {
    public init() {}

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        // Compose the shared thin material so the bordered button's surface,
        // backdrop blur, rim, and refraction all come from the active design
        // style. The `.swui-button-secondary` rule feeds the secondary surface
        // token in as the (opaque) material tint.
        ButtonStyleResult(
            classNames: [
                "swui-button",
                "swui-button-secondary",
                MaterialClass.material,
                MaterialClass.thin,
                configuration.controlSize.className,
                configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
            ],
            style: .custom("--swui-control-tint", configuration.tint)
        )
    }
}
