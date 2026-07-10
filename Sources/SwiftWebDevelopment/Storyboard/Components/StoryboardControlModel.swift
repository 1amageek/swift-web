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
    StoryboardOption("squareBorder", "Square"),
]

let storyboardTintSwatches = [
    StoryboardSwatch("accent", ".accent", "var(--swui-accent)"),
    StoryboardSwatch("danger", ".danger", "var(--swui-danger)"),
    StoryboardSwatch("green", ".green", "#34c759"),
    StoryboardSwatch("blue", ".blue", "#007aff"),
    StoryboardSwatch("purple", ".purple", "#af52de"),
    StoryboardSwatch("pink", ".pink", "#ff2d55"),
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
            .segmented(label: "arrangement", key: "preset", options: [.init("sidebar", "Sidebar"), .init("halves", "Halves"), .init("thirds", "Thirds"), .init("quarters", "Quarters"), .init("wrapping", "Wrapping"), .init("full", "Full")]),
        ]
    case "spacing":
        return [.segmented(label: "spacing", key: "unit", options: [.init("xsmall", ".xsmall"), .init("small", ".small"), .init("medium", ".medium"), .init("large", ".large")])]
    case "alignment":
        return [
            .segmented(label: "alignment", key: "align", options: alignmentOptions),
            .segmented(label: "target", key: "target", options: [.init("frame", "frame"), .init("stack", "stack"), .init("multiline", "multiline")]),
        ]
    case "hug-fill":
        return [
            .toggle(label: "fill", key: "fill"),
            .segmented(label: "fill alignment", key: "align", options: alignmentOptions),
            .segmented(label: "context", key: "context", options: [.init("standalone", "Standalone"), .init("row", "In a row")]),
        ]
    case "style":
        // The toolbar context is produced by the .toolbar modifier, not a
        // component, so the option describes the place rather than a type.
        return [.segmented(label: "context", key: "ctx", options: [.init("standalone", "Standalone"), .init("list", "In List"), .init("toolbar", "In a toolbar")])]
    case "responsive":
        return [.segmented(label: "size class", key: "bp", options: [.init("compact", "Compact"), .init("regular", "Regular"), .init("large", "Large")])]
    case "safearea":
        return [
            .segmented(label: "context", key: "device", options: [.init("notch", "Notch"), .init("browser", "Browser"), .init("none", "Desktop")]),
            .segmented(label: "ignoresSafeArea", key: "ignore", options: [.init("none", "None"), .init("all", "All"), .init("top", ".top")]),
        ]
    case "materials":
        return [
            .segmented(label: "material", key: "level", options: [.init("ultraThin", "Ultra-thin"), .init("thin", "Thin"), .init("regular", "Regular"), .init("thick", "Thick"), .init("ultraThick", "Ultra-thick")]),
            .segmented(label: "glass", key: "glass", options: [.init("regular", ".regular"), .init("clear", ".clear")]),
            .segmented(label: "tint", key: "tint", options: [.init("none", "None"), .init("blue", ".blue"), .init("pink", ".pink")]),
            .segmented(label: "shape", key: "shape", options: [.init("capsule", "Capsule"), .init("rect", "Rect")]),
            .toggle(label: "interactive", key: "interactive"),
        ]

    // Content
    case "typography":
        return [
            .text(label: "Text", key: "text", placeholder: "Text"),
            .segmented(label: "font", key: "font", options: [.init("largeTitle", "Large Title"), .init("title", "Title"), .init("headline", "Headline"), .init("body", "Body"), .init("footnote", "Footnote"), .init("caption", "Caption")]),
            .segmented(label: "fontWeight", key: "weight", options: [.init("regular", "Regular"), .init("medium", "Medium"), .init("semibold", "Semibold"), .init("bold", "Bold")]),
            .segmented(label: "alignment", key: "align", options: alignmentOptions),
            .swatch(label: "foregroundStyle", key: "fg", options: foregroundSwatches),
            .segmented(label: "as", key: "as", options: [.init("p", "p"), .init("span", "span"), .init("h3", "h3"), .init("code", "code")]),
        ]
    case "image":
        return [
            .segmented(label: "systemName", key: "name", options: [.init("star.fill", "star"), .init("heart.fill", "heart"), .init("bell.badge", "bell"), .init("envelope", "envelope"), .init("gearshape", "gear"), .init("sparkles", "unknown")]),
            .segmented(label: "font", key: "font", options: [.init("body", "body"), .init("title2", "title2"), .init("largeTitle", "largeTitle")]),
            .swatch(label: "foregroundStyle", key: "fg", options: foregroundSwatches),
        ]
    case "asyncimage":
        return [
            .segmented(label: "url", key: "source", options: [.init("photo", "Photo"), .init("broken", "Broken"), .init("none", "nil")]),
            .toggle(label: "placeholder", key: "placeholder"),
            .segmented(label: "scale", key: "scale", options: [.init("1", "1×"), .init("2", "2×")]),
        ]
    case "colorvalue":
        return [
            .swatch(label: "Color", key: "name", options: [
                .init("red", "red", "#ff3b30"), .init("orange", "orange", "#ff9500"),
                .init("yellow", "yellow", "#ffcc00"), .init("green", "green", "#34c759"),
                .init("blue", "blue", "#007aff"), .init("indigo", "indigo", "#5856d6"),
                .init("purple", "purple", "#af52de"), .init("pink", "pink", "#ff2d55"),
            ]),
            .range(label: "opacity", key: "opacity", min: 0, max: 1, step: 0.05, unit: .decimal),
        ]
    case "code":
        return [
            .segmented(label: "language", key: "lang", options: [.init("swift", "Swift"), .init("json", "JSON"), .init("bash", "Bash")]),
            .toggle(label: "showsLineNumbers", key: "lineNumbers"),
            .range(label: "startLine", key: "startLine", min: 1, max: 99, step: 1, unit: .integer),
        ]

    // Layout & organization
    case "label":
        return [
            .text(label: "Title", key: "title", placeholder: "Title"),
            .segmented(label: "systemImage", key: "name", options: [.init("checkmark.seal.fill", "seal"), .init("heart.fill", "heart"), .init("pin.fill", "pin")]),
            .segmented(label: "font", key: "font", options: [.init("title3", "title3"), .init("body", "body"), .init("caption", "caption")]),
            .swatch(label: "foregroundStyle", key: "fg", options: foregroundSwatches),
        ]
    case "groupbox":
        return [
            .text(label: "Label", key: "title", placeholder: "Label"),
            .segmented(label: "Padding", key: "pad", options: [.init("compact", "Compact"), .init("regular", "Regular"), .init("roomy", "Roomy")]),
            .toggle(label: "icon label", key: "icon"),
        ]
    case "grid":
        return [
            .range(label: "horizontalSpacing", key: "hSpacing", min: 0, max: 40, step: 4, unit: .pixels),
            .range(label: "verticalSpacing", key: "vSpacing", min: 0, max: 40, step: 4, unit: .pixels),
            .segmented(label: "alignment", key: "align", options: alignmentOptions),
        ]
    case "list":
        return [.segmented(label: "listStyle", key: "style", options: [.init("plain", "Plain"), .init("inset", "Inset"), .init("grouped", "Grouped"), .init("insetGrouped", "Inset Grouped"), .init("sidebar", "Sidebar")])]
    case "section":
        return [
            .text(label: "Header", key: "title", placeholder: "Header"),
            .text(label: "Footer", key: "footer", placeholder: "Footer"),
        ]
    case "disclosuregroup":
        return [
            .text(label: "Label", key: "title", placeholder: "Label"),
            .toggle(label: "isExpanded", key: "open"),
            .toggle(label: "icon label", key: "icon"),
        ]
    case "lazy":
        return [
            .segmented(label: "kind", key: "kind", options: [.init("stack", "Stack"), .init("grid", "Grid")]),
            .segmented(label: "Axis", key: "axis", options: [.init("vstack", "LazyVStack"), .init("hstack", "LazyHStack")]),
            .segmented(label: "tracks", key: "tracks", options: [.init("flexible", "Flexible"), .init("adaptive", "Adaptive")]),
        ]
    case "tabview":
        return [
            .segmented(label: "selection", key: "tab", options: [.init("summary", "Summary"), .init("activity", "Activity"), .init("settings", "Settings")]),
            .toggle(label: "icons", key: "icons"),
        ]
    case "stacks":
        return [.segmented(label: "Axis", key: "axis", options: [.init("v", "VStack"), .init("h", "HStack"), .init("z", "ZStack")])]
    case "spacer":
        return [
            .segmented(label: "Spacer", key: "pos", options: [.init("leading", "Leading"), .init("between", "Between"), .init("trailing", "Trailing"), .init("distributed", "Distributed")]),
            .segmented(label: "axis", key: "axis", options: [.init("horizontal", "Horizontal"), .init("vertical", "Vertical")]),
        ]
    case "divider":
        return [
            .segmented(label: "orientation", key: "orientation", options: [.init("horizontal", "Horizontal"), .init("vertical", "Vertical")]),
            .toggle(label: "constrained", key: "constrained"),
        ]
    case "scrollview":
        return [
            .segmented(label: "axes", key: "axes", options: [.init("vertical", "Vertical"), .init("horizontal", "Horizontal")]),
            .range(label: "height", key: "height", min: 100, max: 220, step: 10, unit: .pixels),
            .toggle(label: "showsIndicators", key: "showsIndicators"),
        ]
    case "toolbar":
        return [
            .text(label: "Primary", key: "label", placeholder: "Primary"),
            .segmented(label: "placement", key: "placement", options: [.init("navigation", "Navigation"), .init("principal", "Principal"), .init("primaryAction", "Primary"), .init("bottomBar", "Bottom")]),
            .toggle(label: "ToolbarItemGroup", key: "group"),
        ]

    // Menus & actions
    case "button":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Prominence", key: "prominence", options: [.init("primary", "Primary"), .init("secondary", "Secondary")]),
            .toggle(label: "icon", key: "icon"),
            .segmented(label: "labelStyle", key: "labelStyle", options: [.init("titleAndIcon", "Title + Icon"), .init("iconOnly", "Icon only")]),
            .toggle(label: "fill width", key: "fill"),
        ]
    case "button-styles":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Style", key: "style", options: [.init("glass", "Glass"), .init("glassProminent", "Prominent"), .init("bordered", "Bordered"), .init("borderedProminent", "Bordered+"), .init("plain", "Plain")]),
            .segmented(label: "controlSize", key: "size", options: [.init("mini", "Mini"), .init("small", "Small"), .init("regular", "Regular"), .init("large", "Large")]),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "control-sizes":
        return [
            .text(label: "Content", key: "label", placeholder: "Content"),
            .segmented(label: "Size", key: "size", options: [.init("mini", "Mini"), .init("small", "Small"), .init("regular", "Regular"), .init("large", "Large"), .init("extraLarge", "XL")]),
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
            .segmented(label: "Style", key: "style", options: [.init("plain", "Plain"), .init("glass", "Glass"), .init("glassProminent", "Prominent"), .init("bordered", "Bordered"), .init("borderedProminent", "Bordered+")]),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
            .toggle(label: "icon", key: "icon"),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "menu":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .toggle(label: "icon", key: "icon"),
            .toggle(label: "disabled", key: "disabled"),
        ]

    // Navigation & search
    case "navigationstack":
        return [
            .text(label: "navigationTitle", key: "title", placeholder: "Title"),
            .toggle(label: "row icons", key: "icons"),
        ]
    case "navigationlink":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .toggle(label: "icon", key: "icon"),
            .segmented(label: "Style", key: "style", options: [.init("plain", "Plain"), .init("bordered", "Bordered")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "searchable":
        return [
            .text(label: "Query", key: "query", placeholder: "Search folders"),
            .text(label: "prompt", key: "prompt", placeholder: "Prompt"),
        ]

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
            .segmented(label: "controlSize", key: "size", options: [.init("small", "Small"), .init("regular", "Regular"), .init("large", "Large")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "securefield":
        return [
            .text(label: "Value", key: "value", placeholder: "Value"),
            .segmented(label: "textFieldStyle", key: "fieldStyle", options: fieldStyleOptions),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "texteditor":
        return [
            .text(label: "Text", key: "value", placeholder: "Text"),
            .segmented(label: "textFieldStyle", key: "fieldStyle", options: [.init("automatic", "Automatic"), .init("plain", "Plain")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "form":
        return [
            .toggle(label: "action", key: "hasAction"),
            .segmented(label: "method", key: "method", options: [.init("get", "GET"), .init("post", "POST")]),
            .text(label: "path", key: "action", placeholder: "/path"),
        ]
    case "toggle":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .toggle(label: "isOn", key: "on"),
            .segmented(label: "toggleStyle", key: "style", options: [.init("switch", "Switch"), .init("checkbox", "Checkbox")]),
            .segmented(label: "controlSize", key: "size", options: [.init("small", "Small"), .init("regular", "Regular"), .init("large", "Large")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "slider":
        return [
            .range(label: "value", key: "value", min: 0, max: 1, step: 0.05, unit: .decimal),
            .toggle(label: "stepped", key: "stepped"),
            .swatch(label: "tint", key: "tint", options: storyboardTintSwatches),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "stepper":
        return [
            .range(label: "value", key: "value", min: 0, max: 8, step: 1, unit: .integer),
            .swatch(label: "tint", key: "tint", options: storyboardTintSwatches),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "picker":
        return [
            .segmented(label: "Selection", key: "value", options: [.init("list", "List"), .init("grid", "Grid"), .init("columns", "Columns")]),
            .segmented(label: "pickerStyle", key: "style", options: [.init("segmented", "Segmented"), .init("menu", "Menu"), .init("inline", "Inline")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "datepicker":
        return [
            .segmented(label: "displayedComponents", key: "components", options: [.init("date", ".date"), .init("time", ".hourAndMinute"), .init("dateAndTime", "Both")]),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "calendar":
        return [
            .segmented(label: "weekdaySymbols", key: "weekdays", options: [.init("short", "Short"), .init("narrow", "Narrow")]),
            .toggle(label: "event markers", key: "events"),
        ]
    case "colorpicker":
        return [
            .color(label: "selection", key: "value"),
            .toggle(label: "disabled", key: "disabled"),
        ]
    case "color":
        return [
            .swatch(label: "Color", key: "name", options: [
                .init("red", "red", "#ff3b30"), .init("orange", "orange", "#ff9500"),
                .init("yellow", "yellow", "#ffcc00"), .init("green", "green", "#34c759"),
                .init("blue", "blue", "#007aff"), .init("indigo", "indigo", "#5856d6"),
                .init("purple", "purple", "#af52de"), .init("pink", "pink", "#ff2d55"),
            ]),
            .range(label: "opacity", key: "opacity", min: 0, max: 1, step: 0.05, unit: .decimal),
            .color(label: ".css(_:)", key: "custom"),
        ]

    // Status
    case "progressview":
        return [
            .range(label: "value", key: "value", min: 0, max: 1, step: 0.05, unit: .decimal),
            .toggle(label: "indeterminate", key: "indeterminate"),
            .toggle(label: "label", key: "label"),
        ]
    case "gauge":
        return [
            .range(label: "value", key: "value", min: 0, max: 1, step: 0.01, unit: .decimal),
            .swatch(label: "tint", key: "tint", options: storyboardTintSwatches),
        ]
    case "badge":
        return [
            .text(label: "Label", key: "label", placeholder: "Label"),
            .segmented(label: "kind", key: "kind", options: [.init("text", "Text"), .init("count", "Count")]),
            .swatch(label: "Tint", key: "tint", options: storyboardTintSwatches),
        ]

    // Animation
    case "animation", "withanimation":
        return [
            .toggle(label: "animate", key: "on"),
            .segmented(label: "curve", key: "curve", options: [.init("easeInOut", "easeInOut"), .init("easeIn", "easeIn"), .init("easeOut", "easeOut"), .init("linear", "linear"), .init("spring", "spring")]),
            .range(label: "duration", key: "duration", min: 0.1, max: 1.2, step: 0.1, unit: .decimal),
            .toggle(label: "bounce", key: "bounce"),
        ]
    case "transition":
        return [
            .toggle(label: "isShown", key: "on"),
            .segmented(label: "transition", key: "kind", options: [.init("opacity", ".opacity"), .init("scale", ".scale"), .init("move", ".move"), .init("slide", ".slide"), .init("asymmetric", "asymmetric")]),
        ]

    default:
        return []
    }
}

// MARK: - Defaults

/// Initial knob and live preview state values, keyed `"componentID.value"`.
let storyboardControlDefaults: [String: String] = [
    "gridsystem.cols": "12", "gridsystem.gutter": "medium", "gridsystem.preset": "sidebar",
    "spacing.unit": "medium",
    "alignment.align": "center", "alignment.target": "frame",
    "hug-fill.fill": "true", "hug-fill.align": "center", "hug-fill.context": "standalone",
    "style.ctx": "standalone",
    "responsive.bp": "large",
    "safearea.device": "notch", "safearea.ignore": "none",
    "materials.level": "regular", "materials.glass": "regular", "materials.tint": "none", "materials.shape": "rect", "materials.interactive": "false",
    "typography.text": "Hello, SwiftWebUI", "typography.font": "largeTitle", "typography.weight": "bold", "typography.align": "center", "typography.fg": "primary", "typography.as": "p",
    "image.name": "star.fill", "image.font": "largeTitle", "image.fg": "accent",
    "asyncimage.source": "photo", "asyncimage.placeholder": "true", "asyncimage.scale": "1",
    "colorvalue.name": "blue", "colorvalue.opacity": "1",
    "code.lang": "swift", "code.lineNumbers": "true", "code.startLine": "1",
    "label.title": "Verified", "label.name": "checkmark.seal.fill", "label.font": "title3", "label.fg": "primary",
    "groupbox.title": "Storage", "groupbox.pad": "regular", "groupbox.icon": "false",
    "grid.hSpacing": "12", "grid.vSpacing": "12", "grid.align": "center",
    "list.style": "plain",
    "section.title": "Account", "section.footer": "Signed in as ada@example.com",
    "disclosuregroup.title": "Advanced options", "disclosuregroup.open": "true", "disclosuregroup.icon": "false",
    "lazy.kind": "stack", "lazy.axis": "vstack", "lazy.tracks": "flexible",
    "tabview.tab": "summary", "tabview.icons": "true",
    "stacks.axis": "h",
    "spacer.pos": "between", "spacer.axis": "horizontal",
    "divider.orientation": "horizontal", "divider.constrained": "false",
    "scrollview.axes": "vertical", "scrollview.height": "160", "scrollview.showsIndicators": "true",
    "toolbar.label": "Back", "toolbar.placement": "primaryAction", "toolbar.group": "false",
    "button.label": "Button", "button.prominence": "primary", "button.icon": "false", "button.labelStyle": "titleAndIcon", "button.fill": "false",
    "button-styles.label": "Glass", "button-styles.style": "glass", "button-styles.size": "regular", "button-styles.tint": "accent", "button-styles.disabled": "false",
    "control-sizes.label": "Button", "control-sizes.size": "regular",
    "button-states.label": "Button", "button-states.tint": "accent", "button-states.disabled": "false",
    "links.label": "Documentation", "links.style": "glassProminent", "links.tint": "accent", "links.icon": "false", "links.disabled": "false",
    "menu.label": "Options", "menu.icon": "false", "menu.disabled": "false",
    "navigationstack.title": "Components", "navigationstack.icons": "false",
    "navigationlink.label": "Overview", "navigationlink.icon": "false", "navigationlink.style": "plain", "navigationlink.disabled": "false",
    "searchable.query": "", "searchable.prompt": "Search folders",
    "alert.open": "false", "alert.message": "This action cannot be undone.",
    "sheet.open": "false",
    "textfield.placeholder": "Name", "textfield.input": "", "textfield.type": "text", "textfield.fieldStyle": "squareBorder", "textfield.size": "regular", "textfield.disabled": "false",
    "securefield.value": "hunter2", "securefield.fieldStyle": "squareBorder", "securefield.disabled": "false",
    "texteditor.value": "Notes support multiple lines.", "texteditor.fieldStyle": "automatic", "texteditor.disabled": "false",
    "form.hasAction": "true", "form.method": "post", "form.action": "/subscribe", "form.email": "",
    "toggle.label": "Enabled", "toggle.on": "true", "toggle.style": "switch", "toggle.size": "regular", "toggle.disabled": "false",
    "slider.value": "0.6", "slider.stepped": "false", "slider.tint": "accent", "slider.disabled": "false",
    "stepper.value": "3", "stepper.tint": "accent", "stepper.disabled": "false",
    "picker.value": "grid", "picker.style": "segmented", "picker.disabled": "false",
    "datepicker.components": "dateAndTime", "datepicker.disabled": "false",
    "calendar.weekdays": "short", "calendar.events": "true", "calendar.selected": "",
    "colorpicker.value": "#3366ff", "colorpicker.disabled": "false",
    "color.name": "blue", "color.opacity": "1", "color.custom": "#22a06b",
    "progressview.value": "0.35", "progressview.indeterminate": "false", "progressview.label": "true",
    "gauge.value": "0.62", "gauge.tint": "accent",
    "badge.label": "Ready", "badge.kind": "text", "badge.tint": "accent",
    "animation.on": "false", "animation.curve": "easeInOut", "animation.duration": "0.30", "animation.bounce": "false",
    "transition.on": "true", "transition.kind": "scale",
    "withanimation.on": "false", "withanimation.curve": "spring", "withanimation.duration": "0.40", "withanimation.bounce": "true",
]
