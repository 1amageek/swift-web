import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Catalog root

/// The fixed Storyboard shell. Route selection is server-owned; only the live
/// detail demo is hydrated as a client island.
public struct StoryboardCatalog: Component, Sendable {
    private let selection: String

    public init(initialSelection: String = catalogDefaultSelection) {
        self.selection = catalogSelectionID(for: initialSelection)
    }

    public var body: some HTML {
        // Layout geometry lives in the storyboard stylesheet (frame/shell/rail
        // rules) rather than .frame modifiers: attribute wrappers are
        // display:contents and box wrappers are real divs, so classes must sit
        // on the real flex items for the app-frame height chain to hold.
        StoryboardStyleRoot {
            div(.class("swui-storyboard-app")) {
                VStack(spacing: Space.none) {
                    CatalogTopBar()
                    HStack(alignment: .top, spacing: .medium) {
                        CatalogSidebar(selection: selection)
                        CatalogDetail(selection: selection)
                        CatalogInspector(selection: selection)
                    }
                    .class("swui-storyboard-shell")
                }
                .class("swui-storyboard-frame")
            }
        }
    }
}
