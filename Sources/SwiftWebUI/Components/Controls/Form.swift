import SwiftHTML

public struct Form<Content: HTML>: WebUIAttributeComponent {
    private let action: String?
    private let method: FormMethod
    private let attributes: [HTMLAttribute]
    private let content: Content
    @Environment(\.formStyle) private var formStyle: FormStyleKind

    public init(
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.action = nil
        self.method = .post
        self.attributes = attributes
        self.content = content()
    }

    public init(
        action: String,
        method: FormMethod = .post,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.action = action
        self.method = method
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "form",
            attributes: mergedAttributes(
                class: controlClassName("swui-form", formStyle.className),
                extra: formAttributes + attributes
            )
        ) {
            content.environment(\.isInsideForm, true)
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(action: action, method: method, attributes: self.attributes + attributes, content: content)
    }

    private init(action: String?, method: FormMethod, attributes: [HTMLAttribute], content: Content) {
        self.action = action
        self.method = method
        self.attributes = attributes
        self.content = content
    }

    private var formAttributes: [HTMLAttribute] {
        guard let action else {
            return []
        }
        return [.action(action), .method(method)]
    }
}
