import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Layout

struct LayoutDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "spacer":
            spacerDemo(state.control("spacer", "pos"))
        case "divider":
            dividerDemo(state.control("divider", "orientation"))
        case "hug-fill":
            hugFillDemo(state.control("hug-fill", "align"))
        default: // stacks
            stacksDemo(state.control("stacks", "axis"))
        }
    }

    @HTMLBuilder
    private func stacksDemo(_ axis: String) -> some HTML {
        if axis == "v" {
            VStack(spacing: .small) {
                Text("Top")
                Text("Middle")
                Text("Bottom")
            }
        } else {
            HStack(spacing: .small) {
                Text("Leading")
                Text("Center")
                Text("Trailing")
            }
        }
    }

    @HTMLBuilder
    private func spacerDemo(_ pos: String) -> some HTML {
        HStack(spacing: .small) {
            switch pos {
            case "leading":
                Spacer()
                Button("Back")
                Button("Save").buttonStyle(.borderedProminent)
            case "trailing":
                Button("Back")
                Button("Save").buttonStyle(.borderedProminent)
                Spacer()
            default:
                Button("Back")
                Spacer()
                Button("Save").buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @HTMLBuilder
    private func dividerDemo(_ orientation: String) -> some HTML {
        if orientation == "vertical" {
            HStack(spacing: .medium) {
                Text("Edit")
                Divider()
                Text("Share")
                Divider()
                Text("Delete")
            }
            .frame(height: 60)
        } else {
            VStack(alignment: .leading, spacing: .small) {
                Text("Section one")
                Divider()
                Text("Section two")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @HTMLBuilder
    private func hugFillDemo(_ align: String) -> some HTML {
        // The fixed control hugs its content (its visible boundary makes the
        // intrinsic width evaluable); the flexible one fills the row.
        VStack(alignment: .leading, spacing: .small) {
            Button("Fixed").buttonStyle(.bordered)
            Button("Flexible").buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: hugAlignment(align))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hugAlignment(_ value: String) -> Alignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }
}
