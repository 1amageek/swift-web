import SwiftWebUITheme
import SwiftHTML

public enum SearchFieldPlacement: Sendable, Equatable {
    case automatic
    case toolbar
    case sidebar
    case navigationBarDrawer

    var className: String {
        switch self {
        case .automatic:
            "swui-search-placement-automatic"
        case .toolbar:
            "swui-search-placement-toolbar"
        case .sidebar:
            "swui-search-placement-sidebar"
        case .navigationBarDrawer:
            "swui-search-placement-navigationBarDrawer"
        }
    }
}

struct SearchScopeSelectionEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

struct SearchScopeGroupNameEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var searchScopeSelection: String? {
        get { self[SearchScopeSelectionEnvironmentKey.self] }
        set { self[SearchScopeSelectionEnvironmentKey.self] = newValue }
    }

    var searchScopeGroupName: String? {
        get { self[SearchScopeGroupNameEnvironmentKey.self] }
        set { self[SearchScopeGroupNameEnvironmentKey.self] = newValue }
    }
}

public struct SearchSuggestionsModifier<Suggestions: HTML>: ComponentModifier {
    private let suggestions: Suggestions

    init(@HTMLBuilder suggestions: () -> Suggestions) {
        self.suggestions = suggestions()
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element("div", attributes: [.class("swui-search-suggestion-host")]) {
            content
            Element(
                "div",
                attributes: [
                    .class("swui-search-suggestions"),
                    .role("listbox"),
                ]
            ) {
                suggestions
            }
        }
    }
}

public struct SearchScopesModifier<Scopes: HTML>: ComponentModifier {
    private let selection: Binding<String>
    private let scopes: Scopes
    private let sourceFileID: String
    private let sourceLine: Int
    private let sourceColumn: Int

    init(
        selection: Binding<String>,
        sourceFileID: String,
        sourceLine: Int,
        sourceColumn: Int,
        @HTMLBuilder scopes: () -> Scopes
    ) {
        self.selection = selection
        self.scopes = scopes()
        self.sourceFileID = sourceFileID
        self.sourceLine = sourceLine
        self.sourceColumn = sourceColumn
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let selection = self.selection
        let groupName = self.groupName
        Element("div", attributes: [.class("swui-search-scoped")]) {
            Element(
                "div",
                attributes: [
                    .class("swui-search-scopes"),
                    .role("radiogroup"),
                    .aria("label", "Search scopes"),
                    .onChange { event in
                        if let value = event.value {
                            selection.wrappedValue = value
                        }
                    },
                ]
            ) {
                scopes
                    .environment(\.searchScopeSelection, selection.wrappedValue)
                    .environment(\.searchScopeGroupName, groupName)
            }
            content
        }
    }

    private var groupName: String {
        let raw = "\(sourceFileID)-\(sourceLine)-\(sourceColumn)"
        let sanitized = String(raw.map { character in
            character.isLetter || character.isNumber ? character : "-"
        })
        return "swui-search-scopes-\(sanitized)"
    }
}

public struct SearchTokensModifier<TokenContent: HTML>: ComponentModifier {
    private let tokens: Binding<[String]>
    private let tokenContent: @Sendable (String) -> TokenContent

    init(
        tokens: Binding<[String]>,
        @HTMLBuilder token: @escaping @Sendable (String) -> TokenContent
    ) {
        self.tokens = tokens
        self.tokenContent = token
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let tokens = self.tokens
        Element("div", attributes: [.class("swui-search-tokenized")]) {
            Element("div", attributes: [.class("swui-search-tokens")]) {
                ForEach(tokens.wrappedValue, id: { token in token }) { token in
                    Element(
                        "button",
                        attributes: [
                            .class("swui-search-token"),
                            .type(ButtonType.button),
                            .data("search-token", token),
                            .aria("label", "Remove \(token)"),
                            .onClick {
                                var values = tokens.wrappedValue
                                values.removeAll { $0 == token }
                                tokens.wrappedValue = values
                            },
                        ]
                    ) {
                        tokenContent(token)
                    }
                }
            }
            content
        }
    }
}

public struct SearchScope: WebUIAttributeComponent {
    private let title: String
    private let value: String
    private let attributes: [HTMLAttribute]

    @Environment(\.searchScopeSelection) private var searchScopeSelection: String?
    @Environment(\.searchScopeGroupName) private var searchScopeGroupName: String?
    @Environment(\.isEnabled) private var isEnabled: Bool

    public init(_ title: String, value: String, _ attributes: HTMLAttribute...) {
        self.title = title
        self.value = value
        self.attributes = attributes
    }

    public init(_ title: String, value: Int, _ attributes: HTMLAttribute...) {
        self.init(title: title, value: String(value), attributes: attributes)
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("label", attributes: [.class("swui-search-scope")]) {
            Element("input", attributes: inputAttributes, isVoid: true)
            span(.class("swui-search-scope-label")) {
                title
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, value: value, attributes: self.attributes + attributes)
    }

    private init(title: String, value: String, attributes: [HTMLAttribute]) {
        self.title = title
        self.value = value
        self.attributes = attributes
    }

    private var inputAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [
            .class("swui-search-scope-input"),
            .type(.radio),
            .value(value),
            .data("search-scope", value),
        ]
        if let searchScopeGroupName {
            result.append(.name(searchScopeGroupName))
        }
        if searchScopeSelection == value {
            result.append(.checked)
        }
        if !isEnabled {
            result.append(.disabled)
        }
        result.append(contentsOf: attributes)
        return result
    }
}

/// A modifier that marks its content as searchable, mirroring SwiftUI
/// `.searchable(text:)`.
///
/// The search field lowers to a `role="search"` region holding a native
/// `<input type="search">` bound to `text`; typing updates the binding live
/// through `oninput`. The field composes the shared thin material so its fill and
/// backdrop blur track the active design style, matching the other form chrome.
public struct SearchableModifier: ComponentModifier {
    private let text: Binding<String>
    private let isPresented: Binding<Bool>?
    private let placement: SearchFieldPlacement
    private let prompt: String

    init(
        text: Binding<String>,
        isPresented: Binding<Bool>? = nil,
        placement: SearchFieldPlacement,
        prompt: String
    ) {
        self.text = text
        self.isPresented = isPresented
        self.placement = placement
        self.prompt = prompt
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let isPresented = self.isPresented?.wrappedValue ?? true
        Element(
            "div",
            attributes: [
                .class("swui-searchable \(placement.className) \(LayoutClass.fillHorizontal)"),
                .data("search-presented", isPresented ? "true" : "false"),
            ]
        ) {
            if isPresented {
                searchField
            }
            content
        }
    }

    @HTMLBuilder
    private var searchField: some HTML {
        let text = self.text
        Element(
            "div",
            attributes: [
                .class("swui-search-bar"),
                .role("search"),
            ]
        ) {
            Element(
                "input",
                attributes: searchInputAttributes(text: text),
                isVoid: true
            )
        }
    }

    private func searchInputAttributes(text: Binding<String>) -> [HTMLAttribute] {
        [
            .class("swui-search-field \(MaterialClass.material) \(MaterialClass.thin)"),
            .type(InputType.search),
            .placeholder(prompt),
            .aria("label", prompt),
            .value(text),
            .onInput { event in
                text.wrappedValue = event.value ?? ""
            },
        ]
    }
}

public extension HTML {
    func searchable(
        text: Binding<String>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil
    ) -> ModifiedContent<Self, SearchableModifier> {
        modifier(SearchableModifier(
            text: text,
            placement: placement,
            prompt: prompt ?? "Search"
        ))
    }

    func searchable(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil
    ) -> ModifiedContent<Self, SearchableModifier> {
        modifier(SearchableModifier(
            text: text,
            isPresented: isPresented,
            placement: placement,
            prompt: prompt ?? "Search"
        ))
    }

    func searchable<Suggestions: HTML>(
        text: Binding<String>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil,
        @HTMLBuilder suggestions: () -> Suggestions
    ) -> some HTML {
        searchable(text: text, placement: placement, prompt: prompt)
            .searchSuggestions(suggestions)
    }

    func searchable<Suggestions: HTML>(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil,
        @HTMLBuilder suggestions: () -> Suggestions
    ) -> some HTML {
        searchable(text: text, isPresented: isPresented, placement: placement, prompt: prompt)
            .searchSuggestions(suggestions)
    }

    func searchable<TokenContent: HTML>(
        text: Binding<String>,
        tokens: Binding<[String]>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil,
        @HTMLBuilder token: @escaping @Sendable (String) -> TokenContent
    ) -> some HTML {
        searchable(text: text, placement: placement, prompt: prompt)
            .searchTokens(tokens, token: token)
    }

    func searchable<TokenContent: HTML, Suggestions: HTML>(
        text: Binding<String>,
        tokens: Binding<[String]>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String? = nil,
        @HTMLBuilder token: @escaping @Sendable (String) -> TokenContent,
        @HTMLBuilder suggestions: () -> Suggestions
    ) -> some HTML {
        searchable(text: text, placement: placement, prompt: prompt, suggestions: suggestions)
            .searchTokens(tokens, token: token)
    }

    func searchSuggestions<Suggestions: HTML>(
        @HTMLBuilder _ suggestions: () -> Suggestions
    ) -> ModifiedContent<Self, SearchSuggestionsModifier<Suggestions>> {
        modifier(SearchSuggestionsModifier(suggestions: suggestions))
    }

    func searchCompletion(_ completion: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("search-completion", completion),
            .role("option"),
        ], role: .semantic))
    }

    func searchScopes<Scopes: HTML>(
        _ selection: Binding<String>,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @HTMLBuilder scopes: () -> Scopes
    ) -> ModifiedContent<Self, SearchScopesModifier<Scopes>> {
        modifier(SearchScopesModifier(
            selection: selection,
            sourceFileID: fileID,
            sourceLine: line,
            sourceColumn: column,
            scopes: scopes
        ))
    }

    func searchTokens<TokenContent: HTML>(
        _ tokens: Binding<[String]>,
        @HTMLBuilder token: @escaping @Sendable (String) -> TokenContent
    ) -> ModifiedContent<Self, SearchTokensModifier<TokenContent>> {
        modifier(SearchTokensModifier(tokens: tokens, token: token))
    }
}

public extension WebUIAttributeMutableHTML {
    func searchCompletion(_ completion: String) -> Self {
        addingAttributes([
            .data("search-completion", completion),
            .role("option"),
        ])
    }
}
