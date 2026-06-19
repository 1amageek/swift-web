import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/storyboard")
struct StoryboardPage {
    var title: String {
        get async {
            "SwiftWebUI Storyboard"
        }
    }

    var description: String? {
        get async {
            "A design-system catalog of every SwiftWebUI component."
        }
    }

    // The page emits its own chrome CSS, then the catalog. Selection is owned
    // by the route; global appearance/style-system controls remain client
    // state inside the catalog.
    @HTMLBuilder
    func body() -> some HTML {
        StoryboardStylesheet()
        StoryboardCatalog()
    }
}

@Page("/storyboard/:selection")
struct StoryboardSelectionPage {
    struct Params: Decodable, Sendable {
        let selection: String
    }

    private var selectionID: String {
        catalogSelectionID(for: params.selection)
    }

    var title: String {
        get async {
            if let item = catalogItem(for: selectionID) {
                return "\(item.name) - SwiftWebUI Storyboard"
            }
            return "SwiftWebUI Storyboard"
        }
    }

    var description: String? {
        get async {
            catalogItem(for: selectionID)?.summary
        }
    }

    @HTMLBuilder
    func body() -> some HTML {
        StoryboardStylesheet()
        StoryboardCatalog(initialSelection: selectionID)
    }
}
