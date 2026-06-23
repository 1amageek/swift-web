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
                Badge("Top")
                Badge("Middle")
                Badge("Bottom")
            }
        } else {
            HStack(spacing: .small) {
                Badge("Leading")
                Badge("Center")
                Badge("Trailing")
            }
        }
    }

    @HTMLBuilder
    private func spacerDemo(_ pos: String) -> some HTML {
        HStack(spacing: .small) {
            switch pos {
            case "leading":
                Badge("leading")
                Spacer()
            case "trailing":
                Spacer()
                Badge("trailing")
            default:
                Badge("leading")
                Spacer()
                Badge("trailing")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @HTMLBuilder
    private func dividerDemo(_ orientation: String) -> some HTML {
        if orientation == "vertical" {
            HStack(spacing: .medium) {
                Text("Leading")
                Divider()
                Text("Trailing")
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
        HStack(spacing: .small) {
            Badge("frame(maxWidth: .infinity)")
            Text("aligns within the row").foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .background(Color.accent.opacity(0.12))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: hugAlignment(align))
    }

    private func hugAlignment(_ value: String) -> Alignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }
}
