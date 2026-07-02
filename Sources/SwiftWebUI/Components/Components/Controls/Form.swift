import SwiftWebUITheme
import SwiftHTML

/// A container that groups controls used for data entry.
///
/// Without an `action`, the group is purely presentational and lowers to a
/// `<div>` rather than a `<form>`. A real `<form>` without an `action` would
/// enable implicit submission: pressing Enter in a contained text field would
/// issue a GET request to the current URL, reloading the page and leaking
/// field values into the query string. Buttons with a server action still
/// work inside the presentational group; each wraps itself in its own
/// dedicated `<form>`.
///
/// With `action`, the container lowers to a real `<form>` that submits the
/// contained named controls to the given path.
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
        if let action {
            Element(
                "form",
                attributes: mergedAttributes(
                    class: controlClassName("swui-form", formStyle.className),
                    extra: [.action(action), .method(method)] + attributes
                )
            ) {
                content.environment(\.isInsideForm, true)
            }
        } else {
            // `isInsideForm` stays false here so a server-action Button takes
            // its standalone path and wraps itself in a working `<form>`.
            Element(
                "div",
                attributes: mergedAttributes(
                    class: controlClassName("swui-form", formStyle.className),
                    extra: attributes
                )
            ) {
                content
            }
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
}
