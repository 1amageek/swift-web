import SwiftHTML

@resultBuilder
public enum GridContentBuilder {
    public static func buildBlock() -> GridContent<EmptyHTML> {
        GridContent(content: EmptyHTML(), maximumColumnCount: 0)
    }

    public static func buildPartialBlock<Content: HTML>(
        first: GridContent<Content>
    ) -> GridContent<Content> {
        first
    }

    public static func buildPartialBlock<Accumulated: HTML, Next: HTML>(
        accumulated: GridContent<Accumulated>,
        next: GridContent<Next>
    ) -> GridContent<TupleComponent2<Accumulated, Next>> {
        GridContent(
            content: TupleComponent2(accumulated.content, next.content),
            maximumColumnCount: Swift.max(
                accumulated.maximumColumnCount,
                next.maximumColumnCount
            )
        )
    }

    public static func buildExpression<Content: HTML>(
        _ expression: GridRow<Content>
    ) -> GridContent<GridRow<Content>> {
        GridContent(content: expression, maximumColumnCount: expression.cellCount)
    }

    public static func buildExpression<Content: HTML>(
        _ expression: Content
    ) -> GridContent<Content> {
        GridContent(content: expression, maximumColumnCount: 0)
    }

    public static func buildExpression(_ expression: String) -> GridContent<text> {
        buildExpression(text(expression))
    }

    public static func buildExpression(_ expression: Int) -> GridContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildExpression(_ expression: Double) -> GridContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildExpression(_ expression: Bool) -> GridContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildOptional<Content: HTML>(
        _ component: GridContent<Content>?
    ) -> GridContent<OptionalComponent<Content>> {
        GridContent(
            content: OptionalComponent(component?.content),
            maximumColumnCount: component?.maximumColumnCount ?? 0
        )
    }

    public static func buildEither<TrueContent: HTML, FalseContent: HTML>(
        first component: GridContent<TrueContent>
    ) -> GridContent<ConditionalComponent<TrueContent, FalseContent>> {
        GridContent(
            content: .first(component.content),
            maximumColumnCount: component.maximumColumnCount
        )
    }

    public static func buildEither<TrueContent: HTML, FalseContent: HTML>(
        second component: GridContent<FalseContent>
    ) -> GridContent<ConditionalComponent<TrueContent, FalseContent>> {
        GridContent(
            content: .second(component.content),
            maximumColumnCount: component.maximumColumnCount
        )
    }

    public static func buildArray<Content: HTML>(
        _ components: [GridContent<Content>]
    ) -> GridContent<ArrayComponent<Content>> {
        var maximumColumnCount = 0
        var content: [Content] = []
        content.reserveCapacity(components.count)
        for component in components {
            content.append(component.content)
            maximumColumnCount = Swift.max(
                maximumColumnCount,
                component.maximumColumnCount
            )
        }
        return GridContent(
            content: ArrayComponent(content),
            maximumColumnCount: maximumColumnCount
        )
    }

    public static func buildLimitedAvailability<Content: HTML>(
        _ component: GridContent<Content>
    ) -> GridContent<Content> {
        component
    }
}
