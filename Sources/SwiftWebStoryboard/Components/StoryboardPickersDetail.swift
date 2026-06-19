import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Pickers & menus

struct PickersDetail: Component {
    let selection: String
    let pick: Binding<String>
    let segment: Binding<String>
    let scope: Binding<String>
    let menuPick: Binding<String>

    var body: some HTML {
        switch selection {
        case "menu":
            Menu("Options") {
                Button("Duplicate") {}
                Button("Move…") {}
                Button("Delete") {}
            }
        default:
            Picker("View", selection: segment) {
                PickerOption("List", value: "list")
                PickerOption("Grid", value: "grid")
                PickerOption("Columns", value: "columns")
            }
            .pickerStyle(.segmented)
        }
    }
}
