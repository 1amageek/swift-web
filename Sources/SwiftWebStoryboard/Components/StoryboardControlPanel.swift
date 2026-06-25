import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Binding helpers

/// Derive a `String` binding into the shared `ui` dictionary for `"id.key"`.
private func stringBinding(_ ui: Binding<[String: String]>, _ fullKey: String) -> Binding<String> {
    Binding(
        get: { ui.wrappedValue[fullKey] ?? storyboardControlDefaults[fullKey] ?? "" },
        set: { ui.wrappedValue[fullKey] = $0 }
    )
}

private func boolBinding(_ ui: Binding<[String: String]>, _ fullKey: String) -> Binding<Bool> {
    Binding(
        get: { (ui.wrappedValue[fullKey] ?? storyboardControlDefaults[fullKey] ?? "false") == "true" },
        set: { ui.wrappedValue[fullKey] = $0 ? "true" : "false" }
    )
}

private func doubleBinding(_ ui: Binding<[String: String]>, _ fullKey: String, _ unit: ControlUnit) -> Binding<Double> {
    Binding(
        get: { Double(ui.wrappedValue[fullKey] ?? storyboardControlDefaults[fullKey] ?? "") ?? 0 },
        set: { ui.wrappedValue[fullKey] = formatControlNumber($0, unit) }
    )
}

/// Stored form of a range value (clean enough to echo in the snippet).
func formatControlNumber(_ value: Double, _ unit: ControlUnit) -> String {
    switch unit {
    case .integer, .pixels: return String(Int(value.rounded()))
    case .decimal: return String(format: "%.2f", value)
    }
}

/// Human-readable readout shown beside a slider.
private func controlReadout(_ value: Double, _ unit: ControlUnit) -> String {
    switch unit {
    case .decimal: return String(format: "%.2f", value)
    case .integer: return String(Int(value.rounded()))
    case .pixels: return "\(Int(value.rounded()))px"
    }
}

// MARK: - Control panel

/// The preview's control panel: a horizontal, wrapping bar of `LABEL + widget`
/// rows that drive the shared `ui` state. Rendered for every component that
/// declares controls. See INFORMATION_ARCHITECTURE.md.
struct StoryboardControlPanel: Component {
    let id: String
    let ui: Binding<[String: String]>

    var body: some HTML {
        let controls = storyboardControls(for: id)
        if !controls.isEmpty {
            div(.class("swui-storyboard-control-panel")) {
                ForEach(controls) { control in
                    controlRow(control)
                }
            }
        }
    }

    @HTMLBuilder
    private func controlRow(_ control: StoryboardControl) -> some HTML {
        HStack(spacing: .small) {
            Text(controlLabel(control), as: .span)
                .font(Font(size: .px(11), weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
            controlWidget(control)
        }
    }

    private func controlLabel(_ control: StoryboardControl) -> String {
        switch control {
        case let .segmented(label, _, _), let .text(label, _, _), let .toggle(label, _),
             let .range(label, _, _, _, _, _), let .swatch(label, _, _), let .color(label, _):
            return label
        }
    }

    @HTMLBuilder
    private func controlWidget(_ control: StoryboardControl) -> some HTML {
        switch control {
        case let .segmented(_, key, options):
            segmentedWidget(key: key, options: options)
        case let .text(_, key, placeholder):
            textWidget(key: key, placeholder: placeholder)
        case let .toggle(_, key):
            Toggle("", isOn: boolBinding(ui, "\(id).\(key)"))
        case let .range(_, key, mn, mx, step, unit):
            rangeWidget(key: key, min: mn, max: mx, step: step, unit: unit)
        case let .swatch(_, key, options):
            swatchWidget(key: key, options: options)
        case let .color(_, key):
            colorWidget(key: key)
        }
    }

    @HTMLBuilder
    private func colorWidget(key: String) -> some HTML {
        let binding = stringBinding(ui, "\(id).\(key)")
        Element("input", attributes: [
            .value(binding),
            .onInput { event in binding.wrappedValue = event.value ?? "#000000" },
            .type(.color),
            .class("swui-storyboard-color-input"),
        ], isVoid: true)
    }

    @HTMLBuilder
    private func textWidget(key: String, placeholder: String) -> some HTML {
        // A bare input bound to `ui` — no field label (the row LABEL names it).
        let binding = stringBinding(ui, "\(id).\(key)")
        Element("input", attributes: [
            .value(binding),
            .onInput { event in binding.wrappedValue = event.value ?? "" },
            .placeholder(placeholder),
            .type(.text),
            .class("swui-storyboard-text-input"),
        ], isVoid: true)
    }

    @HTMLBuilder
    private func segmentedWidget(key: String, options: [StoryboardOption]) -> some HTML {
        let fullKey = "\(id).\(key)"
        let selected = ui.wrappedValue[fullKey] ?? storyboardControlDefaults[fullKey] ?? ""
        HStack(spacing: .xsmall) {
            ForEach(options, id: { option in option.value }) { option in
                Button(action: { ui.wrappedValue[fullKey] = option.value }) {
                    Text(option.label)
                }
                .buttonStyle(.plain)
                .font(Font(size: .px(13), weight: .medium))
                .foregroundStyle(selected == option.value ? .accent : .primary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    Color.surfaceRaised.opacity(selected == option.value ? 1 : 0),
                    in: .rect(cornerRadius: 6)
                )
            }
        }
        .padding(3)
        // A filled track only — no hard outline, matching a native segmented
        // control (the selected segment is the raised chip).
        .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
        .cornerRadius(8)
    }

    @HTMLBuilder
    private func rangeWidget(key: String, min: Double, max: Double, step: Double, unit: ControlUnit) -> some HTML {
        let binding = doubleBinding(ui, "\(id).\(key)", unit)
        HStack(spacing: .small) {
            Slider(value: binding, in: min...max, step: step)
                .frame(width: 132)
            Text(controlReadout(binding.wrappedValue, unit))
                .font(Font(size: .px(13), design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @HTMLBuilder
    private func swatchWidget(key: String, options: [StoryboardSwatch]) -> some HTML {
        let fullKey = "\(id).\(key)"
        let selected = ui.wrappedValue[fullKey] ?? storyboardControlDefaults[fullKey] ?? ""
        HStack(spacing: .xsmall) {
            ForEach(options, id: { swatch in swatch.value }) { swatch in
                Button(action: { ui.wrappedValue[fullKey] = swatch.value }) {
                    div(.class(swatchClass(swatch, selected: selected == swatch.value))) {}
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.label)
            }
        }
    }

    private func swatchClass(_ swatch: StoryboardSwatch, selected: Bool) -> String {
        [
            "swui-storyboard-swatch",
            selected ? "swui-storyboard-swatch-selected" : "swui-storyboard-swatch-unselected",
            "swui-storyboard-swatch-\(swatch.value)",
        ].joined(separator: " ")
    }
}
