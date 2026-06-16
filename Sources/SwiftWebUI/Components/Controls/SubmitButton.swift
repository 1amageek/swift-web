import SwiftHTML

public struct SubmitButton: WebUIAttributeComponent {
    private let text: String
    private let prominence: ButtonProminence
    private let attributes: [HTMLAttribute]

    public init(_ text: String, prominence: ButtonProminence = .secondary) {
        self.text = text
        self.prominence = prominence
        self.attributes = []
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "button",
            attributes: mergedAttributes(
                class: prominence.className,
                extra: [.type(ButtonType.submit)] + attributes
            )
        ) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text: text, prominence: prominence, attributes: self.attributes + attributes)
    }

    private init(text: String, prominence: ButtonProminence, attributes: [HTMLAttribute]) {
        self.text = text
        self.prominence = prominence
        self.attributes = attributes
    }
}
