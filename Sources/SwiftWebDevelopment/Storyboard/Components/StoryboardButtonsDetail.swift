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
            buttonStylesDemo(
                label: content("button-styles"),
                style: state.control("button-styles", "style"),
                size: state.control("button-styles", "size"),
                tint: state.control("button-styles", "tint"),
                disabled: state.controlFlag("button-styles", "disabled")
            )
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
            linkDemo(
                label: content("links"),
                style: state.control("links", "style"),
                tint: state.control("links", "tint"),
                icon: state.controlFlag("links", "icon"),
                disabled: state.controlFlag("links", "disabled")
            )
        default:
            buttonDemo(
                label: content("button"),
                prominence: state.control("button", "prominence"),
                icon: state.controlFlag("button", "icon"),
                labelStyle: state.control("button", "labelStyle"),
                fill: state.controlFlag("button", "fill")
            )
        }
    }

    private func content(_ id: String) -> String {
        let value = state.control(id, "label")
        return value.isEmpty ? "Button" : value
    }

    @HTMLBuilder
    private func buttonDemo(label: String, prominence: String, icon: Bool, labelStyle: String, fill: Bool) -> some HTML {
        if fill {
            styledButton(label: label, prominence: prominence, icon: icon, labelStyle: labelStyle)
                .frame(maxWidth: .infinity)
        } else {
            styledButton(label: label, prominence: prominence, icon: icon, labelStyle: labelStyle)
        }
    }

    @HTMLBuilder
    private func styledButton(label: String, prominence: String, icon: Bool, labelStyle: String) -> some HTML {
        if prominence == "secondary" {
            buttonLabel(label: label, icon: icon, labelStyle: labelStyle)
        } else {
            buttonLabel(label: label, icon: icon, labelStyle: labelStyle)
                .buttonStyle(.borderedProminent)
        }
    }

    @HTMLBuilder
    private func buttonLabel(label: String, icon: Bool, labelStyle: String) -> some HTML {
        if icon {
            Button(action: {}) {
                Label(label, systemImage: "star.fill")
                    .labelStyle(labelStyle == "iconOnly" ? .iconOnly : .titleAndIcon)
            }
        } else {
            Button(label)
        }
    }

    @HTMLBuilder
    private func buttonStylesDemo(label: String, style: String, size: String, tint: String, disabled: Bool) -> some HTML {
        Button(label)
            .buttonStyle(buttonStyleKind(style))
            .controlSize(controlSizeValue(size))
            .tint(tintColor(tint))
            .disabled(disabled)
    }

    @HTMLBuilder
    private func linkDemo(label: String, style: String, tint: String, icon: Bool, disabled: Bool) -> some HTML {
        let url = URL(string: "#")!
        linkContent(url: url, label: label, icon: icon, style: style)
            .tint(tintColor(tint))
            .disabled(disabled)
    }

    @HTMLBuilder
    private func linkContent(url: URL, label: String, icon: Bool, style: String) -> some HTML {
        if style == "plain" {
            linkInner(url: url, label: label, icon: icon)
        } else {
            linkInner(url: url, label: label, icon: icon)
                .buttonStyle(buttonStyleKind(style))
        }
    }

    @HTMLBuilder
    private func linkInner(url: URL, label: String, icon: Bool) -> some HTML {
        if icon {
            Link(destination: url) { Label(label, systemImage: "envelope") }
        } else {
            Link(label, destination: url)
        }
    }

    private func buttonStyleKind(_ value: String) -> ButtonStyleKind {
        switch value {
        case "plain": return .plain
        case "glassProminent": return .glassProminent
        case "bordered": return .bordered
        case "borderedProminent": return .borderedProminent
        default: return .glass
        }
    }

    private func controlSizeValue(_ value: String) -> ControlSize {
        switch value {
        case "mini": return .mini
        case "small": return .small
        case "large": return .large
        case "extraLarge": return .extraLarge
        default: return .regular
        }
    }

    private func tintColor(_ value: String) -> Color {
        storyboardTintColor(value)
    }
}

/// Map a tint knob value to its `Color`, shared by every demo that exposes a
/// tint swatch (buttons, links, badge, slider, stepper, gauge). The set mirrors
/// `storyboardTintSwatches`; `primary`/`secondary` remain mapped so previously
/// stored states still resolve.
func storyboardTintColor(_ value: String) -> Color {
    switch value {
    case "danger": return .danger
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "pink": return .pink
    case "primary": return .primary
    case "secondary": return .secondary
    default: return .accent
    }
}
