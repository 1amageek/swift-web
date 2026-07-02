import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview backdrop: a dot-grid canvas with the demo centered
/// on it, matching the design's preview stage.
///
/// The dot color is a `ShapeStyle` (`Color`, defaulting to `.border`), so the
/// grid follows the active color scheme through the Storyboard stylesheet, while
/// the component body exposes only stable class hooks.
struct PreviewCanvas<Content: HTML>: Component {
    var content: Content

    init(dotColor: Color = .border, @HTMLBuilder content: () -> Content) {
        _ = dotColor
        self.content = content()
    }

    var body: some HTML {
        // A flex column that centers the demo on both axes — `justify-content`
        // centers vertically (the canvas has a min-height), `align-items` centers
        // horizontally. The `swui-vstack` class opts the canvas into the
        // framework's fill rules, so a demo with `.frame(maxWidth: .infinity)`
        // (e.g. GridSystem) stretches to full width instead of staying centered.
        div(.class("swui-vstack swui-storyboard-preview-canvas")) {
            // Wrap the demo in an animation scope so that any attribute a control
            // panel changes (color, frost, layout, …) is interpolated in place by
            // the browser, rather than snapping. The `display: contents` scope adds
            // no box, so the demo stays centered.
            content.animation(.easeOut(duration: 0.2), value: 0)
        }
    }
}
