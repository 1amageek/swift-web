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
            spacerDemo(state.control("spacer", "pos"), axis: state.control("spacer", "axis"))
        case "divider":
            dividerDemo(state.control("divider", "orientation"), constrained: state.controlFlag("divider", "constrained"))
        case "hug-fill":
            hugFillDemo(fill: state.controlFlag("hug-fill", "fill"), align: state.control("hug-fill", "align"), context: state.control("hug-fill", "context"))
        default: // stacks
            stacksDemo(state.control("stacks", "axis"))
        }
    }

    @HTMLBuilder
    private func stacksDemo(_ axis: String) -> some HTML {
        switch axis {
        case "v":
            VStack(spacing: .small) {
                Text("Top")
                Text("Middle")
                Text("Bottom")
            }
        case "z":
            ZStack {
                VStack {}
                    .frame(width: 132, height: 76)
                    .background(Color.blue.opacity(0.18), in: .rect(cornerRadius: 12))
                Text("Overlay").font(.caption).fontWeight(.medium)
            }
        default:
            HStack(spacing: .small) {
                Text("Leading")
                Text("Center")
                Text("Trailing")
            }
        }
    }

    @HTMLBuilder
    private func spacerDemo(_ pos: String, axis: String) -> some HTML {
        if axis == "vertical" {
            VStack(alignment: .leading, spacing: .small) {
                spacerContent(pos)
            }
            .frame(maxWidth: .infinity, height: 132, alignment: .leading)
        } else {
            HStack(spacing: .small) {
                spacerContent(pos)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @HTMLBuilder
    private func spacerContent(_ pos: String) -> some HTML {
        switch pos {
        case "leading":
            Spacer()
            Button("Back")
            Button("Save").buttonStyle(.borderedProminent)
        case "trailing":
            Button("Back")
            Button("Save").buttonStyle(.borderedProminent)
            Spacer()
        case "distributed":
            Text("A")
            Spacer()
            Text("B")
            Spacer()
            Text("C")
        default: // between
            Button("Back")
            Spacer()
            Button("Save").buttonStyle(.borderedProminent)
        }
    }

    @HTMLBuilder
    private func dividerDemo(_ orientation: String, constrained: Bool) -> some HTML {
        if orientation == "vertical" {
            HStack(spacing: .medium) {
                Text("Edit")
                dividerElement(constrained: constrained, vertical: true)
                Text("Share")
                dividerElement(constrained: constrained, vertical: true)
                Text("Delete")
            }
            .frame(height: 60)
        } else {
            VStack(alignment: .leading, spacing: .small) {
                Text("Section one")
                dividerElement(constrained: constrained, vertical: false)
                Text("Section two")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @HTMLBuilder
    private func dividerElement(constrained: Bool, vertical: Bool) -> some HTML {
        if constrained {
            if vertical {
                Divider().frame(height: 32)
            } else {
                Divider().frame(width: 120)
            }
        } else {
            Divider()
        }
    }

    @HTMLBuilder
    private func hugFillDemo(fill: Bool, align: String, context: String) -> some HTML {
        // Hug sizes the control to its content; fill makes the frame greedy while
        // the control keeps its intrinsic size, positioned by the alignment.
        if context == "row" {
            HStack(spacing: .small) {
                Button("Cancel").buttonStyle(.bordered)
                hugFillButton(fill: fill, align: align, label: "Continue")
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: .small) {
                hugFillButton(fill: fill, align: align, label: fill ? "Flexible" : "Fixed")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func hugFillButton(fill: Bool, align: String, label: String) -> some HTML {
        if fill {
            Button(label).buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: hugAlignment(align))
                .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 8))
        } else {
            Button(label).buttonStyle(.bordered)
        }
    }

    private func hugAlignment(_ value: String) -> Alignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }
}
