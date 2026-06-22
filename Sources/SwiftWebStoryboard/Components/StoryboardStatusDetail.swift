import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Status

struct StatusDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "gauge":
            Gauge(value: 0.25) { Text("Disk") }
            Gauge(value: 0.62) { Text("CPU") }
            Gauge(value: 0.9) { Text("Memory") }
        default:
            ProgressView("Uploading", value: 0.35)
            ProgressView("Rendering", value: 0.7)
            ProgressView("Loading")
        }
    }
}
