import Foundation
import SwiftHTML

public struct Image: WebUIAttributeComponent {
    private let source: ImageSource
    private let attributes: [HTMLAttribute]

    public init(_ name: String, bundle: Bundle? = nil) {
        self.source = .named(name)
        self.attributes = []
    }

    public init(decorative name: String, bundle: Bundle? = nil) {
        self.source = .decorative(name)
        self.attributes = []
    }

    public init(systemName: String) {
        self.source = .system(systemName)
        self.attributes = []
    }

    @HTMLBuilder
    public var body: some HTML {
        switch source {
        case .named(let name):
            Element(
                "img",
                attributes: mergedAttributes(class: "swui-image", extra: [.src(name), .alt(name)] + attributes),
                isVoid: true
            )
        case .decorative(let name):
            Element(
                "img",
                attributes: mergedAttributes(class: "swui-image", extra: [.src(name), .alt(""), .aria("hidden", "true")] + attributes),
                isVoid: true
            )
        case .system(let name):
            Element(
                "span",
                attributes: mergedAttributes(
                    class: "swui-image swui-symbol",
                    extra: [.role("img"), .aria("label", name), .data("system-image", name)] + attributes
                )
            ) {
                name
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(source: source, attributes: self.attributes + attributes)
    }

    private init(source: ImageSource, attributes: [HTMLAttribute]) {
        self.source = source
        self.attributes = attributes
    }
}

private enum ImageSource: Sendable, Equatable {
    case named(String)
    case decorative(String)
    case system(String)
}
