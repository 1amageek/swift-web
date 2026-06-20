import SwiftHTML

public struct Spacer: WebUIAttributeComponent {
    private let minLength: Length?
    private let attributes: [HTMLAttribute]

    public init(minLength: Length? = nil, _ attributes: HTMLAttribute...) {
        self.minLength = minLength
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("div", attributes: resolvedAttributes)
    }

    private var resolvedAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [.class("swui-spacer")]
        if let minLength {
            result.append(.style(.minWidth(minLength.cssValue)))
        }
        return mergedAttributes(extra: result + attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(minLength: minLength, attributes: self.attributes + attributes)
    }

    private init(minLength: Length?, attributes: [HTMLAttribute]) {
        self.minLength = minLength
        self.attributes = attributes
    }
}
