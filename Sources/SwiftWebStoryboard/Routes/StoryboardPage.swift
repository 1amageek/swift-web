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

    // The page emits its own chrome CSS, then the catalog. The catalog is a
    // single ClientComponent so the sidebar selection and the global
    // appearance/style-system controls drive the detail and inspector live.
    @HTMLBuilder
    func body() -> some HTML {
        style {
            rawHTML(storyboardCSS)
        }

        StoryboardCatalog()
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
"""
