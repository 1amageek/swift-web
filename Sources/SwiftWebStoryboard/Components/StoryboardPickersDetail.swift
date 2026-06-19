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
            CatalogVariant("Automatic (dropdown)") {
                Picker("Export format", selection: pick) {
                    PickerOption("JSON", value: "json")
                    PickerOption("CSV", value: "csv")
                    PickerOption("XML", value: "xml")
                }
            }
            CatalogVariant("Segmented") {
                Picker("View", selection: segment) {
                    PickerOption("List", value: "list")
                    PickerOption("Grid", value: "grid")
                    PickerOption("Columns", value: "columns")
                }
                .pickerStyle(.segmented)
            }
            CatalogVariant("Inline") {
                Picker("Scope", selection: scope) {
                    PickerOption("All", value: "all")
                    PickerOption("Unread", value: "unread")
                    PickerOption("Flagged", value: "flagged")
                }
                .pickerStyle(.inline)
            }
            CatalogVariant("Menu") {
                Picker("Sort by", selection: menuPick) {
                    PickerOption("Name", value: "name")
                    PickerOption("Date", value: "date")
                    PickerOption("Size", value: "size")
                }
                .pickerStyle(.menu)
            }
        }
    }
}

