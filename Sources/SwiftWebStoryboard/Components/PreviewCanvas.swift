import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview backdrop: a dot-grid canvas with the demo centered
/// on it, matching the design's preview stage.
///
/// The dot color is a `ShapeStyle` (`Color`, defaulting to `.border`), so the
/// grid follows the active color scheme. SwiftUI/SwiftWebUI has no canonical
/// ShapeStyle for a repeating dot pattern, so the typed `background-image`
/// payload is encapsulated here in one Storyboard-only component and atomized
/// during render; everything else (sizing, centering, padding) uses SwiftWebUI.
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
        // horizontally. The `swui-vstack` class opts the canvas into the
        // framework's fill rules, so a demo with `.frame(maxWidth: .infinity)`
        // (e.g. GridSystem) stretches to full width instead of staying centered.
        div(.class("swui-vstack"), .style {
            .width("100%")
            .boxSizing("border-box")
            .minHeight("220px")
            .alignItems("center")
            .justifyContent("center")
            .padding("32px")
            .backgroundColor(surface)
            .backgroundImage("radial-gradient(\(dot) 1.1px, transparent 1.1px)")
            .backgroundSize("18px 18px")
        }) {
            // Wrap the demo in an animation scope so that any attribute a control
            // panel changes (color, frost, layout, …) is interpolated in place by
            // the browser, rather than snapping. The `display: contents` scope adds
            // no box, so the demo stays centered.
            content.animation(.easeOut(duration: 0.2), value: 0)
        }
    }
}
