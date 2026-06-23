import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Pickers & menus

struct PickersDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    private var state: [String: String] { ui.wrappedValue }

    var body: some HTML {
        switch selection {
        case "menu":
            Menu(menuLabel) {
                Button("Duplicate") {}
                Button("Move…") {}
                Button("Delete") {}
            }
            .disabled(state.controlFlag("menu", "disabled"))
        default: // picker
            pickerDemo()
        }
    }

    @HTMLBuilder
    private func pickerDemo() -> some HTML {
        if state.control("picker", "style") == "menu" {
            Picker("View", selection: ui.string("picker.value")) { pickerOptions() }
                .pickerStyle(.menu)
        } else {
            Picker("View", selection: ui.string("picker.value")) { pickerOptions() }
                .pickerStyle(.segmented)
        }
    }

    @HTMLBuilder
    private func pickerOptions() -> some HTML {
        PickerOption("List", value: "list")
        PickerOption("Grid", value: "grid")
        PickerOption("Columns", value: "columns")
    }

    private var menuLabel: String {
        let value = state.control("menu", "label")
        return value.isEmpty ? "Options" : value
    }
}
