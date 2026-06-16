public protocol ButtonStyle: Sendable {
    func resolve(
        configuration: ButtonStyleConfiguration,
        context: StyleResolutionContext
    ) -> ButtonStyleResult
}
