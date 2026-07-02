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
                .frame(width: 220)
        default:
            progressDemo()
        }
    }

    @HTMLBuilder
    private func progressDemo() -> some HTML {
        if state.controlFlag("progressview", "indeterminate") {
            ProgressView("Loading")
                .frame(width: 220)
        } else {
            ProgressView("Progress", value: state.controlNumber("progressview", "value"))
                .frame(width: 220)
        }
    }
}
