import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Buttons & actions

struct ButtonsDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "button-styles":
            buttonStylesDemo(label: content("button-styles"), style: state.control("button-styles", "style"))
        case "control-sizes":
            Button(content("control-sizes"))
                .buttonStyle(.borderedProminent)
                .controlSize(controlSizeValue(state.control("control-sizes", "size")))
        case "button-states":
            Button(content("button-states"))
                .buttonStyle(.borderedProminent)
                .tint(tintColor(state.control("button-states", "tint")))
                .disabled(state.controlFlag("button-states", "disabled"))
        case "links":
            linkDemo(label: content("links"), style: state.control("links", "style"), tint: state.control("links", "tint"))
        default:
            buttonDemo(label: content("button"), prominence: state.control("button", "prominence"))
        }
    }

    private func content(_ id: String) -> String {
        let value = state.control(id, "label")
        return value.isEmpty ? "Button" : value
    }

    @HTMLBuilder
    private func buttonDemo(label: String, prominence: String) -> some HTML {
        if prominence == "secondary" {
            Button(label)
        } else {
            Button(label).buttonStyle(.borderedProminent)
        }
    }

    @HTMLBuilder
    private func buttonStylesDemo(label: String, style: String) -> some HTML {
        switch style {
        case "plain":
            Button(label).buttonStyle(.plain)
        case "glassProminent":
            Button(label).buttonStyle(.glassProminent)
        default:
            Button(label).buttonStyle(.glass)
        }
    }

    @HTMLBuilder
    private func linkDemo(label: String, style: String, tint: String) -> some HTML {
        let url = URL(string: "#")!
        switch style {
        case "plain":
            Link(label, destination: url).tint(tintColor(tint))
        case "glass":
            Link(label, destination: url).buttonStyle(.glass).tint(tintColor(tint))
        default:
            Link(label, destination: url).buttonStyle(.glassProminent).tint(tintColor(tint))
        }
    }

    private func controlSizeValue(_ value: String) -> ControlSize {
        switch value {
        case "mini": return .mini
        case "small": return .small
        case "large": return .large
        default: return .regular
        }
    }

    private func tintColor(_ value: String) -> Color {
        switch value {
        case "danger": return .danger
        case "primary": return .primary
        case "secondary": return .secondary
        default: return .accent
        }
    }
}
