import SwiftWebUITheme
import SwiftHTML

/// A run of read-only text, mirroring SwiftUI's `Text`.
///
/// The initializer is SwiftUI-canonical: `Text("…")` takes only the string (plus
/// the standard HTML-attribute modifiers). Choosing the HTML element a run
/// renders into — `<p>`, `<span>`, the headings, `<code>`, `<pre>`, `<label>`,
/// and so on (see `TextElement`) — is a **web-specific extension exposed as the
/// `as(_:)` modifier**, not an initializer argument: SwiftUI has no notion of an
/// HTML element, so the selector stays out of the SwiftUI-parity initializer.
///
/// Being a modifier also lets the selector compose with `#if`, so platform- or
/// target-conditional markup can add or drop the element without rebuilding the
/// call. A bare `Text("…")` renders as `<p>`; reach for `.as(_:)` only when a
/// specific element is required.
public struct Text: AttributeComponent {
    private let value: String
    private let element: TextElement
    private let attributes: [HTMLAttribute]

    /// Creates a text run, mirroring SwiftUI's `Text(_:)`. It renders as a
    /// paragraph; use the `as(_:)` modifier to emit a different HTML element.
    public init(
        _ value: String,
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.element = .p
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        // `as` selects only the tag; it never contributes a style class. The
        // single `swui-text` class normalizes every element's typography to the
        // inherited baseline (see the stylesheet), so `.as(.code)` and `.as(.h1)`
        // are visually identical to a bare `Text` until a modifier styles them.
        Element(element.tagName, attributes: mergedAttributes(class: "swui-text", extra: attributes)) {
            value
        }
    }

    /// Renders this text as the given HTML `element` instead of the default
    /// `<p>`. A web-specific extension exposed as a modifier so it composes with
    /// `#if` — see the type documentation.
    public func `as`(_ element: TextElement) -> Self {
        Self(value, element: element, attributes: attributes)
    }

    /// Renders this text as the HTML element named `tag` (`"h1"`, `"label"`,
    /// `"p"`, …). Known tag names resolve to their semantic `TextElement`;
    /// anything else renders as a custom element.
    public func `as`(_ tag: String) -> Self {
        `as`(TextElement(tag))
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
}
