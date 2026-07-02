import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Media

struct MediaDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "label":
            let title = state.control("label", "title")
            Label(title.isEmpty ? "Verified" : title, systemImage: state.control("label", "name"))
                .font(.title2)
        default: // image
            Image(systemName: state.control("image", "name"))
                .font(.largeTitle)
                .foregroundStyle(.accent)
        }
    }
}
