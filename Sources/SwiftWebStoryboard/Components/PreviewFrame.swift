import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview frame: a full-width rounded, bordered container that
/// holds the dot-grid canvas and (optionally) the control area beneath it.
///
/// It is a width-100% block so it always fills the content column, sidestepping
/// the modifier-wrapper width-collapse that `.background/.border/.cornerRadius`
/// chains hit. The border color is a `ShapeStyle` (`Color`, theme-adaptive); the
/// raw border/radius lives in this one Storyboard-only component.
struct PreviewFrame<Content: HTML>: Component {
    var borderColor: Color
    var content: Content

    init(borderColor: Color = .border, @HTMLBuilder content: () -> Content) {
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some HTML {
        let border = borderColor.resolve(in: .default).cssValue
        div(.style {
            .width("100%")
            .boxSizing("border-box")
            .border("1px solid \(border)")
            .borderRadius("12px")
            .overflow("hidden")
        }) {
            content
        }
    }
}
