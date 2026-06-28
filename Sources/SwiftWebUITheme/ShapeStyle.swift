public protocol ShapeStyle: Sendable {
    func resolve(in context: StyleResolutionContext) -> ResolvedStyle
}
