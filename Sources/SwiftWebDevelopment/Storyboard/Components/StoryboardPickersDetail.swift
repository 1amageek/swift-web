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
            menuDemo()
        default: // picker
            pickerDemo()
        }
    }

    @HTMLBuilder
    private func menuDemo() -> some HTML {
        let disabled = state.controlFlag("menu", "disabled")
        if state.controlFlag("menu", "icon") {
            Menu {
                menuItems()
            } label: {
                Label(menuLabel, systemImage: "person.crop.circle")
            }
            .disabled(disabled)
        } else {
            Menu(menuLabel) {
                menuItems()
            }
            .disabled(disabled)
        }
    }

    @HTMLBuilder
    private func menuItems() -> some HTML {
        Button("Duplicate") {}
        Button("Move") {}
        Button("Delete") {}
    }

    @HTMLBuilder
    private func pickerDemo() -> some HTML {
        Picker("View", selection: ui.string("picker.value")) { pickerOptions() }
            .pickerStyle(pickerStyleKind(state.control("picker", "style")))
            .disabled(state.controlFlag("picker", "disabled"))
    }

    private func pickerStyleKind(_ value: String) -> PickerStyleKind {
        switch value {
        case "menu": return .menu
        case "inline": return .inline
        default: return .segmented
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
