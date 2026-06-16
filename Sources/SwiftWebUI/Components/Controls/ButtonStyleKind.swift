public enum ButtonStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case bordered
    case borderedProminent
    case plain

    func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        switch self {
        case .automatic:
            AutomaticButtonStyle().resolve(configuration: configuration, context: context)
        case .bordered:
            BorderedButtonStyle().resolve(configuration: configuration, context: context)
        case .borderedProminent:
            BorderedProminentButtonStyle().resolve(configuration: configuration, context: context)
        case .plain:
            PlainButtonStyle().resolve(configuration: configuration, context: context)
        }
    }
}
