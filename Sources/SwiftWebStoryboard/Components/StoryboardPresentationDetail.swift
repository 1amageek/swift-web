import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Presentation

struct PresentationDetail: Component {
    let selection: String
    let showsAlert: Binding<Bool>
    let showsConfirmation: Binding<Bool>
    let showsSheet: Binding<Bool>
    let showsPopover: Binding<Bool>

    var body: some HTML {
        switch selection {
        case "sheet":
            HStack(spacing: .small) {
                Button("Show sheet") { showsSheet.wrappedValue = true }
                Button("Show popover") { showsPopover.wrappedValue = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: showsSheet) {
                VStack(alignment: .leading, spacing: .medium) {
                    Heading("Sheet", level: .section)
                    Text("A sheet composes the thick material and lifts to the top layer.", tone: .muted)
                    Button("Done") { showsSheet.wrappedValue = false }
                }
            }
            .popover(isPresented: showsPopover) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Popover content anchored to its source.", tone: .muted)
                    Button("Close") { showsPopover.wrappedValue = false }
                }
            }
        default:
            HStack(spacing: .small) {
                Button("Show alert") { showsAlert.wrappedValue = true }
                Button("Show confirmation") { showsConfirmation.wrappedValue = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .alert("Delete this draft?", isPresented: showsAlert) {
                Button("Delete", action: Action.post("/storyboard/delete"))
            } message: {
                Text("This action cannot be undone.")
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: showsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", action: Action.post("/storyboard/discard"))
                Button("Keep editing") { showsConfirmation.wrappedValue = false }
            }
        }
    }
}

