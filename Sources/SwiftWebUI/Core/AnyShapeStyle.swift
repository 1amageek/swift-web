public struct AnyShapeStyle: ShapeStyle {
    private let resolver: @Sendable (StyleResolutionContext) -> ResolvedStyle

    public init<S: ShapeStyle>(_ style: S) {
        self.resolver = { context in
            style.resolve(in: context)
        }
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        resolver(context)
    }
}
