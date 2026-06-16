public protocol WebShapeStyle: Sendable {
    func resolve(in context: StyleResolutionContext) -> ResolvedStyle
}
