public struct AutomaticButtonStyle: ButtonStyle {
    public init() {}

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        switch configuration.prominence {
        case .primary:
            BorderedProminentButtonStyle().resolve(configuration: configuration, context: context)
        case .secondary:
            BorderedButtonStyle().resolve(configuration: configuration, context: context)
        }
    }
}
