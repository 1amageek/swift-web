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
        StoryboardStyleRoot {
            VStack(spacing: Space.none) {
                CatalogTopBar()
                Divider()
                HStack(alignment: .top, spacing: Space.none) {
                    CatalogSidebar(selection: selection)
                    Divider()
                    CatalogDetail(selection: selection)
                    Divider()
                    CatalogInspector(selection: selection)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .preferredColorScheme(.light)
        }
    }
}
