import SwiftHTML

/// A modifier that marks its content as searchable, mirroring SwiftUI
/// `.searchable(text:)`.
///
/// The search field lowers to a `role="search"` region holding a native
/// `<input type="search">` bound to `text`; typing updates the binding live
/// through `oninput`. The field composes the shared thin material so its fill and
/// backdrop blur track the active design style, matching the other form chrome.
public struct SearchableModifier: ComponentModifier {
    private let text: Binding<String>
    private let prompt: String

    init(text: Binding<String>, prompt: String) {
        self.text = text
        self.prompt = prompt
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let text = self.text
        Element(
            "div",
            attributes: [.class("swui-searchable \(LayoutClass.fillHorizontal)")]
        ) {
            Element(
                "div",
                attributes: [
                    .class("swui-search-bar"),
                    .role("search"),
                ]
            ) {
                // `<input>` is a replaced element, so the material's
                // `::before` rim/refraction overlay does not paint here — the
                // fill and backdrop blur still apply.
                Element(
                    "input",
                    attributes: [
                        .class("swui-search-field \(MaterialClass.material) \(MaterialClass.thin)"),
                        .type(InputType.search),
                        .placeholder(prompt),
                        .aria("label", prompt),
                        .value(text),
                        .onInput { event in
                            text.wrappedValue = event.value ?? ""
                        },
                    ],
                    isVoid: true
                )
            }
            content
        }
    }
}

public extension HTML {
    func searchable(
        text: Binding<String>,
        prompt: String = "Search"
    ) -> ModifiedContent<Self, SearchableModifier> {
        modifier(SearchableModifier(text: text, prompt: prompt))
    }
}
