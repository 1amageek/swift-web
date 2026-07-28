import SwiftHTML

@resultBuilder
public enum GridRowContentBuilder {
    public static func buildBlock() -> GridRowContent<EmptyHTML> {
        GridRowContent(content: EmptyHTML(), cellCount: 0)
    }

    public static func buildPartialBlock<Content: Component>(
        first: GridRowContent<Content>
    ) -> GridRowContent<Content> {
        first
    }

    public static func buildPartialBlock<Accumulated: Component, Next: Component>(
        accumulated: GridRowContent<Accumulated>,
        next: GridRowContent<Next>
    ) -> GridRowContent<Group<ComponentContent>> {
        GridRowContent(
            content: Group {
                accumulated.content
                next.content
            },
            cellCount: accumulated.cellCount + next.cellCount
        )
    }

    public static func buildExpression<Content: Component>(
        _ expression: Content
    ) -> GridRowContent<Content> {
        GridRowContent(content: expression, cellCount: 1)
    }

    public static func buildExpression(_ expression: String) -> GridRowContent<text> {
        buildExpression(text(expression))
    }

    public static func buildExpression(_ expression: Int) -> GridRowContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildExpression(_ expression: Double) -> GridRowContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildExpression(_ expression: Bool) -> GridRowContent<text> {
        buildExpression(text(String(expression)))
    }

    public static func buildOptional<Content: Component>(
        _ component: GridRowContent<Content>?
    ) -> GridRowContent<OptionalComponent<Content>> {
        GridRowContent(
            content: OptionalComponent(component?.content),
            cellCount: component?.cellCount ?? 0
        )
    }

    public static func buildEither<TrueContent: Component, FalseContent: Component>(
        first component: GridRowContent<TrueContent>
    ) -> GridRowContent<ConditionalComponent<TrueContent, FalseContent>> {
        GridRowContent(
            content: .first(component.content),
            cellCount: component.cellCount
        )
    }

    public static func buildEither<TrueContent: Component, FalseContent: Component>(
        second component: GridRowContent<FalseContent>
    ) -> GridRowContent<ConditionalComponent<TrueContent, FalseContent>> {
        GridRowContent(
            content: .second(component.content),
            cellCount: component.cellCount
        )
    }

    public static func buildArray<Content: Component>(
        _ components: [GridRowContent<Content>]
    ) -> GridRowContent<ArrayComponent<Content>> {
        var cellCount = 0
        var content: [Content] = []
        content.reserveCapacity(components.count)
        for component in components {
            content.append(component.content)
            cellCount += component.cellCount
        }
        return GridRowContent(
            content: ArrayComponent(content),
            cellCount: cellCount
        )
    }

    public static func buildLimitedAvailability<Content: Component>(
        _ component: GridRowContent<Content>
    ) -> GridRowContent<Content> {
        component
    }
}
