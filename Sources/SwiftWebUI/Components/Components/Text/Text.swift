import SwiftWebUITheme
import SwiftHTML

/// A run of read-only text, mirroring SwiftUI's `Text`.
///
/// SwiftWebUI extends `Text` with an `as:` selector that chooses the HTML
/// element it renders into — `<p>`, `<span>`, the headings, `<code>`, `<pre>`,
/// and so on (see `TextElement`). This is an **intentional, web-specific part of
/// the API, not a SwiftUI-parity gap**: SwiftUI has no notion of an HTML element,
/// so there is no canonical name to mirror. `as:` lets callers emit semantic
/// HTML without leaving the `Text` abstraction, in the same sanctioned-exception
/// category as the HTML-attribute modifiers (`.id`, `.class`, `.data`).
///
/// It defaults to `.p`, so a bare `Text("…")` matches SwiftUI; reach for `as:`
/// (or the `as(_:)` modifier) only when a specific element is required.
public struct Text: WebUIAttributeComponent {
    private let value: String
    private let element: TextElement
    private let attributes: [HTMLAttribute]

    /// Creates a text run that renders as `element` (a paragraph by default).
    ///
    /// `as:` is an intentional, web-specific spec — see the type documentation.
    public init(
        _ value: String,
        as element: TextElement = .p,
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.element = element
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(element.tagName, attributes: mergedAttributes(class: className, extra: attributes)) {
            value
        }
    }

    /// Re-renders this text as a different HTML `element`. Intentional,
    /// web-specific spec — see the type documentation.
    public func `as`(_ element: TextElement) -> Self {
        Self(value, element: element, attributes: attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value, element: element, attributes: self.attributes + attributes)
    }

    private init(_ value: String, element: TextElement, attributes: [HTMLAttribute]) {
        self.value = value
        self.element = element
        self.attributes = attributes
    }

    var plainValue: String {
        value
    }

    private var className: String {
        var classes = ["swui-text"]
        switch element {
        case .code:
            classes.append("swui-inline-code")
        case .pre:
            classes.append("swui-preformatted")
        case .h1:
            classes.append(contentsOf: ["swui-heading", "swui-heading-page"])
        case .h2:
            classes.append(contentsOf: ["swui-heading", "swui-heading-section"])
        case .h3:
            classes.append(contentsOf: ["swui-heading", "swui-heading-subsection"])
        case .h4, .h5, .h6:
            classes.append("swui-heading")
        default:
            break
        }
        return classes.joined(separator: " ")
    }
}
