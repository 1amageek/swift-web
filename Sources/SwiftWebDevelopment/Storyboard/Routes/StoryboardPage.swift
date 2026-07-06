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
            "A theme catalog of every SwiftWebUI component."
        }
    }

    // The catalog is a fixed, viewport-filling app shell whose columns scroll
    // internally, so the page opts into the viewport body surface.
    var bodyClass: String? {
        "swui-viewport"
    }

    func body() -> some HTML {
        StoryboardCatalog(scheme: StoryboardSchemePreference.currentFromRequest())
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

    var bodyClass: String? {
        "swui-viewport"
    }

    func body() -> some HTML {
        StoryboardCatalog(
            initialSelection: selectionID,
            scheme: StoryboardSchemePreference.currentFromRequest()
        )
    }
}

private extension StoryboardSchemePreference {
    static func currentFromRequest() -> Self {
        guard let rawValue = RequestContext.current?.request.cookies[cookieName] else {
            return .auto
        }
        return Self(rawValue: rawValue) ?? .auto
    }
}
