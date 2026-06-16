import SwiftHTML

public struct BorderedProminentButtonStyle: ButtonStyle {
    public init() {}

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        ButtonStyleResult(
            classNames: [
                "swui-button",
                "swui-button-primary",
                configuration.controlSize.className,
                configuration.isEnabled ? "swui-control-enabled" : "swui-control-disabled",
            ],
            style: .custom("--swui-control-tint", configuration.tint)
        )
    }
}
