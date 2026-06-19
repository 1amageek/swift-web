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
        style {
            rawHTML(storyboardCSS)
        }

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
        style {
            rawHTML(storyboardCSS)
        }

        StoryboardCatalog(initialSelection: selectionID)
    }
}

let storyboardCSS = """
html { scroll-behavior: smooth; }
body { margin: 0; }
.storyboard-page {
    height: 100vh;
    min-height: 100vh;
    overflow: hidden;
    background:
        radial-gradient(1200px 520px at 50% -8%, color-mix(in srgb, var(--swui-accent) 8%, transparent), transparent),
        var(--swui-background);
    color: var(--swui-text);
    font-family: var(--swui-font-family);
}

.storyboard-page,
.storyboard-page * {
    box-sizing: border-box;
}

/* Offset in-page anchor jumps so the sticky top bar never covers a target. */
.storyboard-page [id] {
    scroll-margin-top: 72px;
}

.storyboard-sidebar-link {
    display: flex;
    width: 100%;
    min-height: 32px;
    align-items: center;
    justify-content: flex-start;
    padding: 6px 10px;
    border-radius: 8px;
    color: var(--swui-text);
    text-align: left;
    text-decoration: none;
    white-space: nowrap;
    font-size: 0.9em;
    font-weight: 450;
}

.storyboard-sidebar-link:hover {
    background: color-mix(in srgb, var(--swui-text) 7%, transparent);
}

.storyboard-sidebar-link.is-selected {
    background: color-mix(in srgb, var(--swui-accent) 14%, transparent);
    color: var(--swui-accent);
    font-weight: 600;
}
"""
