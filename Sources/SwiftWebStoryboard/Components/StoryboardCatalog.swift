import Foundation
import SwiftHTML
import SwiftWebUI
#if canImport(SwiftWebUIRuntime)
import SwiftWebUIRuntime
#endif

// MARK: - Catalog root

/// The full component catalog as a single client component. The current
/// selection is route-owned; this component owns the interactive demo state and
/// the top-bar controls that retheme the page by re-applying the environment.
public struct StoryboardCatalog: ClientComponent, Sendable {
    private let selection: String
    @State private var theme = Theme.light
    @State private var name = "Ada Lovelace"
    @State private var email = "ada@example.com"
    @State private var secret = "hunter2"
    @State private var notes = "Notes support multiple lines."
    @State private var enabled = true
    @State private var volume = 0.6
    @State private var density = 3
    @State private var due = Date(timeIntervalSince1970: 1_718_000_000)
    @State private var accent = "#3366ff"
    @State private var pick = "json"
    @State private var segment = "grid"
    @State private var scope = "all"
    @State private var menuPick = "name"
    @State private var tab = "summary"
    @State private var query = ""
    @State private var showsAlert = false
    @State private var showsConfirmation = false
    @State private var showsSheet = false
    @State private var showsPopover = false
    @State private var advancedOptionsExpanded = true
    @State private var animateOn = false
    // Unified control-panel state, keyed "componentID.knob" (see INFORMATION_ARCHITECTURE.md).
    @State private var ui: [String: String] = [:]

    public init(initialSelection: String = catalogDefaultSelection) {
        self.selection = catalogSelectionID(for: initialSelection)
    }

    private static func selection(from href: String) -> String {
        guard let url = URL(string: href) else {
            return catalogDefaultSelection
        }
        let pathComponents = url.path.split(separator: "/").map(String.init)
        guard let storyboardIndex = pathComponents.firstIndex(of: "storyboard") else {
            return catalogDefaultSelection
        }
        let selectionIndex = pathComponents.index(after: storyboardIndex)
        guard pathComponents.indices.contains(selectionIndex) else {
            return catalogDefaultSelection
        }
        return pathComponents[selectionIndex]
    }

    public var body: some HTML {
        VStack(spacing: Space.none) {
            CatalogTopBar(theme: $theme)
            Divider()
            HStack(alignment: .top, spacing: Space.none) {
                CatalogSidebar(selection: selection)
                Divider()
                CatalogDetail(
                    selection: selection,
                    name: $name,
                    email: $email,
                    secret: $secret,
                    notes: $notes,
                    enabled: $enabled,
                    volume: $volume,
                    density: $density,
                    due: $due,
                    accent: $accent,
                    pick: $pick,
                    segment: $segment,
                    scope: $scope,
                    menuPick: $menuPick,
                    tab: $tab,
                    query: $query,
                    showsAlert: $showsAlert,
                    showsConfirmation: $showsConfirmation,
                    showsSheet: $showsSheet,
                    showsPopover: $showsPopover,
                    advancedOptionsExpanded: $advancedOptionsExpanded,
                    animateOn: $animateOn,
                    ui: $ui
                )
                Divider()
                CatalogInspector(selection: selection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.theme, theme)
        .environment(\.styleSystem, .swiftWeb)
    }
}

#if canImport(SwiftWebUIRuntime)
extension StoryboardCatalog: ClientWasmBootstrapInitializable {
    public init(bootstrap request: ClientWasmBootstrapRequest) throws {
        self.init(initialSelection: Self.selection(from: request.location.href))
    }
}
#endif
