import SwiftHTML

public struct Picker<Content: HTML>: WebUIAttributeComponent {
    private let title: String
    private let selection: Binding<String>
    private let attributes: [HTMLAttribute]
    private let content: Content
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        selection: Binding<String>,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("label", attributes: [.class("swui-picker-field \(LayoutClass.fillHorizontal)")]) {
            span(.class("swui-field-label")) {
                title
            }
            Element(
                "select",
                attributes: mergedAttributes(
                    class: "swui-picker \(controlSize.className)",
                    extra: selectAttributes
                )
            ) {
                content.environment(\.pickerSelection, selection.wrappedValue)
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, selection: selection, attributes: self.attributes + attributes, content: content)
    }

    private init(
        title: String,
        selection: Binding<String>,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
        self.content = content
    }

    private var selectAttributes: [HTMLAttribute] {
        let selection = self.selection
        var result: [HTMLAttribute] = [
            .value(selection),
            .onChange { event in
                selection.wrappedValue = event.value ?? ""
            },
        ]
        if !isEnabled {
            result.append(.disabled)
            result.append(.aria("disabled", "true"))
        }
        result.append(contentsOf: attributes)
        return result
    }
}
