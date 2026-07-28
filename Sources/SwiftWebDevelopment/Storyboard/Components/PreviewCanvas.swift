import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview stage: the demo centered on a curated gradient
/// scene, so glass and materials always have depth to refract.
struct PreviewCanvas<Content: Component>: Component {
    var scene: StoryboardScene
    var childContent: Content

    init(scene: StoryboardScene = .mist, @HTMLBuilder content: () -> Content) {
        self.scene = scene
        self.childContent = content()
    }

    var content: some Component {
        // A flex column that centers the demo on both axes — `justify-content`
        // centers vertically (the canvas has a min-height), `align-items` centers
        // horizontally. The `swui-vstack` class opts the canvas into the
        // framework's fill rules, so a demo with `.frame(maxWidth: .infinity)`
        // (e.g. GridSystem) stretches to full width instead of staying centered.
        div(.class("swui-vstack swui-storyboard-preview-canvas \(scene.className)")) {
            // Wrap the demo in an animation scope so that any attribute a control
            // panel changes (color, frost, layout, …) is interpolated in place by
            // the browser, rather than snapping. The `display: contents` scope adds
            // no box, so the demo stays centered.
            childContent.animation(.easeOut(duration: 0.2), value: 0)
        }
    }
}
