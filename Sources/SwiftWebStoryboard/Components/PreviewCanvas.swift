import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview backdrop: a dot-grid canvas with the demo centered
/// on it, matching the design's preview stage.
///
/// The dot color is a `ShapeStyle` (`Color`, defaulting to `.border`), so the
/// grid follows the active theme. SwiftUI/SwiftWebUI has no canonical ShapeStyle
/// for a repeating dot pattern, so the `background-image` is encapsulated here in
/// a single Storyboard-only component rather than leaking raw CSS across the
/// catalog; everything else (sizing, centering, padding) uses SwiftWebUI.
struct PreviewCanvas<Content: HTML>: Component {
    var dotColor: Color
    var content: Content

    init(dotColor: Color = .border, @HTMLBuilder content: () -> Content) {
        self.dotColor = dotColor
        self.content = content()
    }

    var body: some HTML {
        let dot = dotColor.resolve(in: .default).cssValue
        let surface = Color.surface.resolve(in: .default).cssValue
        // A flex column that centers the demo on both axes — `justify-content`
        // centers vertically (the canvas has a min-height), `align-items` centers
        // horizontally.
        div(.style {
            .width("100%")
            .boxSizing("border-box")
            .minHeight("220px")
            .display("flex")
            .flexDirection("column")
            .alignItems("center")
            .justifyContent("center")
            .padding("32px")
            .backgroundColor(surface)
            .backgroundImage("radial-gradient(\(dot) 1.1px, transparent 1.1px)")
            .backgroundSize("18px 18px")
        }) {
            content
        }
    }
}
