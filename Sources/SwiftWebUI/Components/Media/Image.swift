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
            if let markup = SFSymbolPaths.markup[name] {
                // Known symbol: draw an approximating SVG glyph that inherits the
                // text color, matching SwiftUI's icon rendering.
                Element(
                    "svg",
                    attributes: mergedAttributes(
                        class: "swui-image swui-symbol",
                        extra: [
                            .role("img"),
                            .aria("label", Self.symbolAccessibilityName(name)),
                            .data("system-image", name),
                            .attribute("viewBox", "0 0 24 24"),
                            .attribute("fill", "currentColor")
                        ] + attributes
                    )
                ) {
                    rawHTML(markup)
                }
            } else {
                // Unknown symbol: surface the identifier rather than render nothing.
                Element(
                    "span",
                    attributes: mergedAttributes(
                        class: "swui-image swui-symbol swui-symbol-text",
                        extra: [.role("img"), .aria("label", Self.symbolAccessibilityName(name)), .data("system-image", name)] + attributes
                    )
                ) {
                    name
                }
            }
        }
    }

    /// A readable accessible name for an SF Symbol identifier. The web has no
    /// access to the symbol's localized description, so the dotted identifier
    /// ("star.fill") is humanised ("star fill") rather than read verbatim
    /// ("star dot fill"). Callers can override with `.accessibilityLabel(_:)`.
    private static func symbolAccessibilityName(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
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
