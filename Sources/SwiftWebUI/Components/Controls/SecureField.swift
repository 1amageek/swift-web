import SwiftHTML

public struct SecureField: WebUIAttributeComponent {
    private let field: TextField

    public init(
        _ title: String,
        text: Binding<String>,
        _ attributes: HTMLAttribute...
    ) {
        self.field = TextField(
            title: title,
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

    private init(field: TextField) {
        self.field = field
    }
}
