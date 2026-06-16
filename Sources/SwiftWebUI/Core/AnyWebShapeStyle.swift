public struct AnyWebShapeStyle: WebShapeStyle {
    private let resolver: @Sendable (StyleResolutionContext) -> ResolvedStyle

    public init<ShapeStyle: WebShapeStyle>(_ style: ShapeStyle) {
        self.resolver = { context in
            style.resolve(in: context)
        }
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        resolver(context)
    }
}
