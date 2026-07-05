import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Status

struct StatusDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "gauge":
            Gauge(value: state.controlNumber("gauge", "value")) { Text("Value") }
                .tint(storyboardTintColor(state.control("gauge", "tint")))
                .frame(width: 220)
        default:
            progressDemo()
        }
    }

    @HTMLBuilder
    private func progressDemo() -> some HTML {
        let hasLabel = state.controlFlag("progressview", "label")
        if state.controlFlag("progressview", "indeterminate") {
            if hasLabel {
                ProgressView("Loading").frame(width: 220)
            } else {
                ProgressView().frame(width: 220)
            }
        } else {
            let value = state.controlNumber("progressview", "value")
            if hasLabel {
                ProgressView("Progress", value: value).frame(width: 220)
            } else {
                ProgressView(value: value).frame(width: 220)
            }
        }
    }
}
