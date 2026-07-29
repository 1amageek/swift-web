import Foundation
import SwiftHTML
import SwiftWebUI

/// The Storyboard's preview frame: a full-width rounded, bordered container that
/// holds the dot-grid canvas and (optionally) the control area beneath it.
///
/// It is a width-100% block so it always fills the content column, sidestepping
/// the modifier-wrapper width-collapse that `.background/.border/.cornerRadius`
/// chains hit. The border/radius recipe lives in the Storyboard stylesheet.
struct PreviewFrame: Component {
    private let childContent: ComponentContent

    init(borderColor: Color = .border, @HTMLBuilder content: () -> ComponentContent) {
        _ = borderColor
        self.childContent = content()
    }

    var content: some Component {
        div(.class("swui-storyboard-preview-frame")) {
            childContent
        }
    }
}
