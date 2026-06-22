import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Status

struct StatusDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "gauge":
            Gauge(value: 0.25) { "Disk" }
            Gauge(value: 0.62) { "CPU" }
            Gauge(value: 0.9) { "Memory" }
        default:
            ProgressView("Uploading", value: 0.35)
            ProgressView("Rendering", value: 0.7)
            ProgressView("Loading")
        }
    }
}
