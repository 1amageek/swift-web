import SwiftWebUITheme
import SwiftHTML

public struct SecureField<Label: HTML>: AttributeComponent {
    private let field: TextField<Label>

    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.field = TextField(
            label: label(),
            placeholder: prompt?.plainValue,
            type: .password,
            attributes: [.value(text), .onInput { event in
                text.wrappedValue = event.value ?? ""
            }] + attributes
        )
    }

    @HTMLBuilder
    public var body: some HTML {
        field
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(field: field.addingAttributes(attributes))
    }

    private init(field: TextField<Label>) {
        self.field = field
    }
}

public extension SecureField where Label == text {
    init(
        _ title: String,
        text: Binding<String>,
        prompt: Text? = nil,
        _ attributes: HTMLAttribute...
    ) {
        // The title renders only as the visible label; without a `prompt`
        // the input carries no placeholder, so the title never shows twice.
        self.init(
            field: TextField(
                label: SwiftHTML.text(title),
                placeholder: prompt?.plainValue,
                type: .password,
                attributes: [.value(text), .onInput { event in
                    text.wrappedValue = event.value ?? ""
                }] + attributes
            )
        )
    }
}
