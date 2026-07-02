import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Presentation

struct PresentationDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    private var state: [String: String] { ui.wrappedValue }

    var body: some HTML {
        switch selection {
        case "sheet":
            Button("Show sheet") { ui.bool("sheet.open").wrappedValue = true }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: ui.bool("sheet.open")) {
                    VStack(alignment: .leading, spacing: .medium) {
                        Heading("Sheet", level: .section)
                        Text("A sheet composes the thick material and lifts to the top layer.")
                            .foregroundStyle(.secondary)
                        Button("Done") { ui.bool("sheet.open").wrappedValue = false }
                    }
                }
        default: // alert
            Button("Show alert") { ui.bool("alert.open").wrappedValue = true }
                .buttonStyle(.borderedProminent)
                .alert("Delete this draft?", isPresented: ui.bool("alert.open")) {
                    Button("Delete", action: Action.post("/storyboard/delete"))
                } message: {
                    Text(alertMessage)
                }
        }
    }

    private var alertMessage: String {
        let value = state.control("alert", "message")
        return value.isEmpty ? "This action cannot be undone." : value
    }
}
