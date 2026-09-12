import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/storyboard")
struct StoryboardPage {
    var document: some HTMLDocument {
        PageDocument(
            title: "SwiftWebUI Storyboard",
            description: "A theme catalog of every SwiftWebUI component.",
            bodyClass: "swui-viewport"
        ) {
            StoryboardCatalog(scheme: StoryboardSchemePreference.currentFromRequest())
        }
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

    var document: some HTMLDocument {
        let item = catalogItem(for: selectionID)
        return PageDocument(
            title: item.map { "\($0.name) - SwiftWebUI Storyboard" } ?? "SwiftWebUI Storyboard",
            description: item?.summary,
            bodyClass: "swui-viewport"
        ) {
            StoryboardCatalog(
                initialSelection: selectionID,
                scheme: StoryboardSchemePreference.currentFromRequest()
            )
        }
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
