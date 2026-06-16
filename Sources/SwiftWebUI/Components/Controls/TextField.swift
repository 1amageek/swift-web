import SwiftHTML

public struct TextField: WebUIAttributeComponent {
    private let title: String
    private let type: InputType
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        text: Binding<String>,
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.type = .text
        self.attributes = [.value(text), .onInput { event in
            text.wrappedValue = event.value ?? ""
        }] + attributes
    }

    init(
        title: String,
        type: InputType,
        attributes: [HTMLAttribute]
    ) {
        self.title = title
        self.type = type
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("label", attributes: [.class("swui-field \(LayoutClass.fillHorizontal)")]) {
            span(.class("swui-field-label")) {
                title
            }
            Element(
                "input",
                attributes: mergedAttributes(
                    class: "swui-text-field \(controlSize.className)",
                    extra: [.type(type), .placeholder(title)] + disabledAttributes + attributes
                ),
                isVoid: true
            )
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, type: type, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }
}
