import Foundation
import SwiftHTML

// MARK: - Control model

/// One knob in a preview's control panel. Six cases cover every component, so
/// every panel looks and behaves the same. See INFORMATION_ARCHITECTURE.md.
enum StoryboardControl: Sendable, Identifiable {
    case segmented(label: String, key: String, options: [StoryboardOption])
    case text(label: String, key: String, placeholder: String)
    case toggle(label: String, key: String)
    case range(label: String, key: String, min: Double, max: Double, step: Double, unit: ControlUnit)
    case swatch(label: String, key: String, options: [StoryboardSwatch])
    case color(label: String, key: String)

    /// The knob key, unique within a component's control list.
    var id: String {
        switch self {
        case let .segmented(_, key, _), let .text(_, key, _), let .toggle(_, key),
             let .range(_, key, _, _, _, _), let .swatch(_, key, _), let .color(_, key):
            return key
        }
    }
}

struct StoryboardOption: Sendable {
    let value: String
    let label: String
    init(_ value: String, _ label: String) {
        self.value = value
        self.label = label
    }
}

struct StoryboardSwatch: Sendable {
    let value: String
    let label: String
    let css: String
    init(_ value: String, _ label: String, _ css: String) {
        self.value = value
        self.label = label
        self.css = css
    }
}

/// How a range's numeric value is formatted in its readout.
enum ControlUnit: Sendable {
    case decimal        // 0.60
    case integer        // 3
    case pixels         // 120px
}

// MARK: - State accessors

/// The storyboard keeps every component's knob values in one `[String: String]`
/// keyed `"componentID.knob"`, so a single `@State` drives controls, demo, and
/// snippet. These helpers read a typed value, falling back to the registered
/// default when the user has not touched the knob.
extension Dictionary where Key == String, Value == String {
    func control(_ id: String, _ key: String) -> String {
        let k = "\(id).\(key)"
        return self[k] ?? storyboardDefaultValue(for: k)
    }

    func controlFlag(_ id: String, _ key: String) -> Bool {
        let fullKey = "\(id).\(key)"
        return storyboardBoolValue(control(id, key), key: fullKey)
    }

    func controlNumber(_ id: String, _ key: String) -> Double {
        let fullKey = "\(id).\(key)"
        return storyboardDoubleValue(control(id, key), key: fullKey)
    }
}

// MARK: - Typed bindings into the shared state

func storyboardDefaultValue(for fullKey: String) -> String {
    guard let value = storyboardControlDefaults[fullKey] else {
        storyboardControlFailure("Missing storyboard control default for \(fullKey)")
        return "__missing_\(fullKey)__"
    }
    return value
}

private func storyboardBoolValue(_ rawValue: String, key: String) -> Bool {
    switch rawValue {
    case "true":
        return true
    case "false":
        return false
    default:
        storyboardControlFailure("Invalid storyboard bool value for \(key): \(rawValue)")
        return false
    }
}

private func storyboardDoubleValue(_ rawValue: String, key: String) -> Double {
    guard let value = Double(rawValue) else {
        storyboardControlFailure("Invalid storyboard numeric value for \(key): \(rawValue)")
        return 0
    }
    return value
}

private func storyboardControlFailure(_ message: String) {
    assertionFailure(message)
}

/// Derive typed bindings into the shared `ui` dictionary so an interactive demo
/// (a real TextField/Toggle/Slider) and its control panel stay linked through
/// the same `"id.knob"` key.
extension Binding where Value == [String: String] {
    func string(_ fullKey: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue[fullKey] ?? storyboardDefaultValue(for: fullKey) },
            set: { self.wrappedValue[fullKey] = $0 }
        )
    }

    func bool(_ fullKey: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { storyboardBoolValue(self.wrappedValue[fullKey] ?? storyboardDefaultValue(for: fullKey), key: fullKey) },
            set: { self.wrappedValue[fullKey] = $0 ? "true" : "false" }
        )
    }

    func double(_ fullKey: String) -> Binding<Double> {
        Binding<Double>(
            get: { storyboardDoubleValue(self.wrappedValue[fullKey] ?? storyboardDefaultValue(for: fullKey), key: fullKey) },
            set: { self.wrappedValue[fullKey] = String(format: "%.2f", $0) }
        )
    }

    func int(_ fullKey: String) -> Binding<Int> {
        Binding<Int>(
            get: {
                Int(storyboardDoubleValue(
                    self.wrappedValue[fullKey] ?? storyboardDefaultValue(for: fullKey),
                    key: fullKey
                ))
            },
            set: { self.wrappedValue[fullKey] = String($0) }
        )
    }
}

// MARK: - Shared option sets

private let alignmentOptions = [
    StoryboardOption("leading", "Leading"),
    StoryboardOption("center", "Center"),
    StoryboardOption("trailing", "Trailing"),
]

private let fieldStyleOptions = [
    StoryboardOption("automatic", "Automatic"),
    StoryboardOption("plain", "Plain"),
    StoryboardOption("roundedBorder", "Rounded"),
]

let storyboardTintSwatches = [
    StoryboardSwatch("accent", ".accent", "var(--swui-accent)"),
    StoryboardSwatch("danger", ".danger", "var(--swui-danger)"),
    StoryboardSwatch("primary", ".primary", "var(--swui-text)"),
    StoryboardSwatch("secondary", ".secondary", "var(--swui-text-muted)"),
]

private let foregroundSwatches = [
    StoryboardSwatch("primary", ".primary", "var(--swui-text)"),
    StoryboardSwatch("secondary", ".secondary", "var(--swui-text-muted)"),
    StoryboardSwatch("accent", ".accent", "var(--swui-accent)"),
    StoryboardSwatch("danger", ".danger", "var(--swui-danger)"),
]

// MARK: - Per-component controls

/// The control panel for a component, chosen to expose its meaningful knobs.
func storyboardControls(for id: String) -> [StoryboardControl] {
    switch id {
    // Foundations
    case "gridsystem":
        return [
            .segmented(label: "columns", key: "cols", options: [.init("12", "12"), .init("8", "8"), .init("4", "4")]),
            .segmented(label: "gutter", key: "gutter", options: [.init("small", ".small"), .init("medium", ".medium"), .init("large", ".large")]),
            .segmented(label: "arrangement", key: "preset", options: [.init("sidebar", "Sidebar"), .init("halves", "Halves"), .init("thirds", "Thirds"), .init("full", "Full")]),
        ]
    case "spacing":
        return [.segmented(label: "spacing", key: "unit", options: [.init("small", ".small"), .init("medium", ".medium"), .init("large", ".large")])]
    case "alignment":
        return [.segmented(label: "alignment", key: "align", options: alignmentOptions)]
    case "hug-fill":
        return [.segmented(label: "fill alignment", key: "align", options: alignmentOptions)]
    case "style":
        return [.segmented(label: "context", key: "ctx", options: [.init("standalone", "Standalone"), .init("list", "In List"), .init("toolbar", "In Toolbar")])]
    case "responsive":
        return [.segmented(label: "size class", key: "bp", options: [.init("compact", "Compact"), .init("regular", "Regular"), .init("large", "Large")])]
    case "safearea":
        return [.segmented(label: "context", key: "device", options: [.init("notch", "Notch"), .init("browser", "Browser"), .init("none", "Desktop")])]
    case "materials":
        return [.segmented(label: "material", key: "level", options: [.init("ultraThin", "Ultra-thin"), .init("thin", "Thin"), .init("regular", "Regular"), .init("thick", "Thick"), .init("ultraThick", "Ultra-thick")])]

    // Content
    case "typography":
        return [
            .text(label: "Text", key: "text", placeholder: "Text"),
            .segmented(label: "font", key: "font", options: [.init("largeTitle", "Large Title"), .init("title", "Title"), .init("headline", "Headline"), .init("body", "Body"), .init("footnote", "Footnote"), .init("caption", "Caption")]),
            .segmented(label: "fontWeight", key: "weight", options: [.init("regular", "Regular"), .init("medium", "Medium"), .init("semibold", "Semibold"), .init("bold", "Bold")]),
            .segmented(label: "alignment", key: "align", options: alignmentOptions),
            .swatch(label: "foregroundStyle", key: "fg", options: foregroundSwatches),
        ]
    case "image":
        return [.segmented(label: "systemName", key: "name", options: [.init("star.fill", "star"), .init("bell.badge", "bell"), .init("gearshape", "gear")])]
    case "colorvalue":
        return [
            .swatch(label: "Color", key: "name", options: [
                .init("blue", "blue", "#007aff"), .init("green", "green", "#34c759"),
                .init("orange", "orange", "#ff9500"), .init("pink", "pink", "#ff2d55"),
                .init("purple", "purple", "#af52de"),
            ]),
            .range(label: "opacity", key: "opacity", min: 0, max: 1, step: 0.05, unit: .decimal),
        ]
    case "code":
        return [
            .segmented(label: "language", key: "lang", options: [.init("swift", "Swift"), .init("json", "JSON"), .init("bash", "Bash")]),
            .toggle(label: "showsLineNumbers", key: "lineNumbers"),
        ]

    // Layout & organization
    case "label":
        return [
            .text(label: "Title", key: "title", placeholder: "Title"),
            .segmented(label: "systemImage", key: "name", options: [.init("checkmark.seal.fill", "seal"), .init("heart.fill", "heart"), .init("pin.fill", "pin")]),
        ]
    case "groupbox":
        return [
            .text(label: "Label", key: "title", placeholder: "Label"),
            .segmented(label: "Padding", key: "pad", options: [.init("compact", "Compact"), .init("regular", "Regular"), .init("roomy", "Roomy")]),
        ]
    case "list":
        return [.segmented(label: "listStyle", key: "style", options: [.init("plain", "Plain"), .init("inset", "Inset"), .init("grouped", "Grouped"), .init("insetGrouped", "Inset Grouped"), .init("sidebar", "Sidebar")])]
    case "section":
        return [
            .text(label: "Header", key: "title", placeholder: "Header"),
            .text(label: "Footer", key: "footer", placeholder: "Footer"),
        ]
    case "disclosuregroup":
        return [.toggle(label: "isExpanded", key: "open")]
    case "lazy":
        return [.segmented(label: "Axis", key: "axis", options: [.init("vstack", "LazyVStack"), .init("hstack", "LazyHStack")])]
    case "tabview":
        return [.segmented(label: "selection", key: "tab", options: [.init("summary", "Summary"), .init("activity", "Activity"), .init("settings", "Settings")])]
    case "stacks":
        return [.segmented(label: "Axis", key: "axis", options: [.init("v", "VStack"), .init("h", "HStack")])]
    case "spacer":
        return [.segmented(label: "Spacer", key: "pos", options: [.init("leading", "Leading"), .init("between", "Between"), .init("trailing", "Trailing")])]
    case "divider":
        return [.segmented(label: "orientation", key: "orientation", options: [.init("horizontal", "Horizontal"), .init("vertical", "Vertical")])]
    case "scrollview":
        return [
            .segmented(label: "axes", key: "axes", options: [.init("vertical", "Vertical"), .init("horizontal", "Horizontal")]),
            .range(label: "height", key: "height", min: 100, max: 220, step: 10, unit: .pixels),
        ]
    case "toolbar":
        return [.text(label: "Primary", key: "label", placeholder: "Primary")]

    // Menus & actions
    case "button":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Prominence", key: "prominence", options: [.init("primary", "Primary"), .init("secondary", "Secondary")]),
        ]
    case "button-styles":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Style", key: "style", options: [.init("glass", "Glass"), .init("glassProminent", "Prominent"), .init("plain", "Plain")]),
        ]
    case "control-sizes":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Size", key: "size", options: [.init("mini", "Mini"), .init("small", "Small"), .init("regular", "Regular"), .init("large", "Large")]),
        ]
    case "button-states":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "links":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .segmented(label: "Style", key: "style", options: [.init("plain", "Plain"), .init("glass", "Glass"), .init("glassProminent", "Prominent")]),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
        ]
    case "menu":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .toggle(label: "disabled", key: "disabled"),
        ]

    // Navigation & search
    case "navigationstack":
        return [.text(label: "navigationTitle", key: "title", placeholder: "Title")]
    case "navigationlink":
        return [.text(label: "Label", key: "label", placeholder: "Label")]
    case "searchable":
        return [.text(label: "Query", key: "query", placeholder: "Search folders")]

    // Presentation
    case "alert":
        return [
            .toggle(label: "isPresented", key: "open"),
            .text(label: "message", key: "message", placeholder: "Message"),
        ]
    case "sheet":
        return [.toggle(label: "isPresented", key: "open")]

    // Selection & input
    case "textfield":
        return [
            .text(label: "Placeholder", key: "placeholder", placeholder: "Placeholder"),
            .segmented(label: ".type", key: "type", options: [.init("text", "text"), .init("email", "email"), .init("url", "url")]),
            .segmented(label: "textFieldStyle", key: "fieldStyle", options: fieldStyleOptions),
        ]
    case "securefield":
        return [
            .text(label: "Value", key: "value", placeholder: "Value"),
            .segmented(label: "textFieldStyle", key: "fieldStyle", options: fieldStyleOptions),
        ]
    case "texteditor":
        return [.text(label: "Text", key: "value", placeholder: "Text")]
    case "form":
        return [
            .segmented(label: "method", key: "method", options: [.init("get", "GET"), .init("post", "POST")]),
            .text(label: "action", key: "action", placeholder: "/path"),
        ]
    case "toggle":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .toggle(label: "isOn", key: "on"),
        ]
    case "slider":
        return [.range(label: "value", key: "value", min: 0, max: 1, step: 0.05, unit: .decimal)]
    case "stepper":
        return [.range(label: "value", key: "value", min: 0, max: 8, step: 1, unit: .integer)]
    case "picker":
        return [
            .segmented(label: "Selection", key: "value", options: [.init("list", "List"), .init("grid", "Grid"), .init("columns", "Columns")]),
            .segmented(label: "pickerStyle", key: "style", options: [.init("segmented", "Segmented"), .init("menu", "Menu")]),
        ]
    case "datepicker":
        return [
            .segmented(label: "datePickerStyle", key: "style", options: [.init("compact", "Compact"), .init("graphical", "Graphical")]),
            .toggle(label: ".hourAndMinute", key: "time"),
        ]
    case "colorpicker":
        return [.color(label: "selection", key: "value")]
    case "color":
        return [.color(label: ".css(_:)", key: "custom")]

    // Status
    case "progressview":
        return [
            .range(label: "value", key: "value", min: 0, max: 1, step: 0.05, unit: .decimal),
            .toggle(label: "indeterminate", key: "indeterminate"),
        ]
    case "gauge":
        return [.range(label: "value", key: "value", min: 0, max: 1, step: 0.01, unit: .decimal)]
    case "badge":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
        ]

    // Animation
    case "animation", "withanimation":
        return [.toggle(label: "animate", key: "on")]
    case "transition":
        return [.toggle(label: "isShown", key: "on")]

    default:
        return []
    }
}

// MARK: - Defaults

/// Initial knob and live preview state values, keyed `"componentID.value"`.
let storyboardControlDefaults: [String: String] = [
    "gridsystem.cols": "12", "gridsystem.gutter": "medium", "gridsystem.preset": "sidebar",
    "spacing.unit": "medium",
    "alignment.align": "center",
    "hug-fill.align": "center",
    "style.ctx": "standalone",
    "responsive.bp": "large",
    "safearea.device": "notch",
    "materials.level": "regular",
    "typography.text": "Hello, SwiftWebUI", "typography.font": "largeTitle", "typography.weight": "bold", "typography.align": "center", "typography.fg": "primary",
    "image.name": "star.fill",
    "colorvalue.name": "blue", "colorvalue.opacity": "1",
    "code.lang": "swift", "code.lineNumbers": "true",
    "label.title": "Verified", "label.name": "checkmark.seal.fill",
    "groupbox.title": "Storage", "groupbox.pad": "regular",
    "list.style": "plain",
    "section.title": "Account", "section.footer": "Signed in as ada@example.com",
    "disclosuregroup.open": "true",
    "lazy.axis": "vstack",
    "tabview.tab": "summary",
    "stacks.axis": "h",
    "spacer.pos": "between",
    "divider.orientation": "horizontal",
    "scrollview.axes": "vertical", "scrollview.height": "160",
    "toolbar.label": "Back",
    "button.label": "Button", "button.prominence": "primary",
    "button-styles.label": "Glass", "button-styles.style": "glass",
    "control-sizes.label": "Button", "control-sizes.size": "regular",
    "button-states.label": "Button", "button-states.tint": "accent", "button-states.disabled": "false",
    "links.label": "Documentation", "links.style": "glassProminent", "links.tint": "accent",
    "menu.label": "Options", "menu.disabled": "false",
    "navigationstack.title": "Components",
    "navigationlink.label": "Overview",
    "searchable.query": "",
    "alert.open": "false", "alert.message": "This action cannot be undone.",
    "sheet.open": "false",
    "textfield.placeholder": "Name", "textfield.input": "", "textfield.type": "text", "textfield.fieldStyle": "roundedBorder",
    "securefield.value": "hunter2", "securefield.fieldStyle": "roundedBorder",
    "texteditor.value": "Notes support multiple lines.",
    "form.method": "post", "form.action": "/subscribe",
    "toggle.label": "Enabled", "toggle.on": "true",
    "slider.value": "0.6",
    "stepper.value": "3",
    "picker.value": "grid", "picker.style": "segmented",
    "datepicker.style": "compact", "datepicker.time": "true",
    "colorpicker.value": "#3366ff",
    "color.custom": "#22a06b",
    "progressview.value": "0.35", "progressview.indeterminate": "false",
    "gauge.value": "0.62",
    "badge.label": "Ready", "badge.tint": "accent",
    "animation.on": "false", "transition.on": "true", "withanimation.on": "false",
]
