public struct AnyButtonStyle: ButtonStyle {
    private let resolver: @Sendable (ButtonStyleConfiguration, StyleResolutionContext) -> ButtonStyleResult

    public init<ConcreteStyle: ButtonStyle>(_ style: ConcreteStyle) {
        self.resolver = { configuration, context in
            style.resolve(configuration: configuration, context: context)
        }
    }

    public func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult {
        resolver(configuration, context)
    }
}

public extension AnyButtonStyle {
    static var automatic: AnyButtonStyle { AnyButtonStyle(AutomaticButtonStyle()) }
    static var bordered: AnyButtonStyle { AnyButtonStyle(BorderedButtonStyle()) }
    static var borderedProminent: AnyButtonStyle { AnyButtonStyle(BorderedProminentButtonStyle()) }
    static var plain: AnyButtonStyle { AnyButtonStyle(PlainButtonStyle()) }
}
