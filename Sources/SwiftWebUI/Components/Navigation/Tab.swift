import SwiftHTML

// The selected tab value, carried from `TabView` to its `Tab` children so each
// tab can mark its radio `checked` when it is the active selection.
struct TabSelectionEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

// The shared radio-group `name`, carried from `TabView` to its `Tab` children so
// the tabs are mutually exclusive natively. The change handler lives on the
// `TabView` container (change events bubble), so tabs only need the group name.
struct TabGroupNameEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var tabSelection: String? {
        get { self[TabSelectionEnvironmentKey.self] }
        set { self[TabSelectionEnvironmentKey.self] = newValue }
    }

    var tabGroupName: String? {
        get { self[TabGroupNameEnvironmentKey.self] }
        set { self[TabGroupNameEnvironmentKey.self] = newValue }
    }
}

/// A page in a `TabView`, mirroring SwiftUI `Tab`.
///
/// Each tab lowers to a `display: contents` unit holding a hidden radio (the tab
/// button) and its `role="tabpanel"` content. The unit flattens into the
/// enclosing `TabView` flex container, so every tab button forms the bar and the
/// active panel sits below it. The active panel is revealed purely in CSS via
/// `:has(.swui-tab-input:checked)`, so tab switching needs no client runtime;
/// the enclosing `TabView` keeps the selection binding in sync through one
/// delegated change handler.
public struct Tab<Content: HTML>: WebUIAttributeComponent {
    private let title: String
    private let systemImage: String?
    private let value: String
    private let attributes: [HTMLAttribute]
    private let content: Content

    @Environment(\.tabSelection) private var tabSelection
    @Environment(\.tabGroupName) private var tabGroupName
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        value: String,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = nil
        self.value = value
        self.attributes = attributes
        self.content = content()
    }

    public init(
        _ title: String,
        systemImage: String,
        value: String,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        // The tab button is interactive glass; the active state fills with the
        // accent. The panel composes no chrome of its own — it hosts the tab's
        // content and is shown only when this tab's radio is checked.
        Element(
            "div",
            attributes: mergedAttributes(class: "swui-tab", extra: attributes)
        ) {
            Element(
                "label",
                attributes: [
                    .class("swui-tab-item \(MaterialClass.glass) \(MaterialClass.interactive) \(MaterialClass.regular)"),
                    .role("tab"),
                    .id(tabControlID),
                    // `role="tab"` requires a selected state; it reflects the
                    // rendered selection (kept current by the runtime, or by the
                    // initial render in the CSS-only degradation).
                    .aria("selected", tabSelection == value ? "true" : "false"),
                    .aria("controls", tabPanelID),
                ]
            ) {
                Element("input", attributes: tabInputAttributes, isVoid: true)
                if let systemImage {
                    span(.class("swui-tab-item-icon")) {
                        Image(systemName: systemImage)
                    }
                }
                span(.class("swui-tab-item-label")) {
                    title
                }
            }
            Element(
                "div",
                attributes: [
                    .class("swui-tab-panel"),
                    .role("tabpanel"),
                    .id(tabPanelID),
                    .aria("labelledby", tabControlID),
                ]
            ) {
                content
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            title: title,
            systemImage: systemImage,
            value: value,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        title: String,
        systemImage: String?,
        value: String,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.attributes = attributes
        self.content = content
    }

    // Stable ids that wire each tab to its panel (`aria-controls`) and back
    // (`aria-labelledby`). Scoped by the group name so multiple tab views on a
    // page do not collide.
    private var tabControlID: String {
        "\(tabIdentifierPrefix)-tab-\(sanitizedValue)"
    }

    private var tabPanelID: String {
        "\(tabIdentifierPrefix)-panel-\(sanitizedValue)"
    }

    private var tabIdentifierPrefix: String {
        tabGroupName ?? "swui-tab"
    }

    private var sanitizedValue: String {
        String(value.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    // The radio carries no change handler of its own: the change event bubbles
    // to the `TabView` container, which reads the fired radio's value to update
    // the selection binding. Its `checked` state is mirrored from `tabSelection`.
    private var tabInputAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [
            .class("swui-tab-input"),
            .type(InputType.radio),
            .value(value),
        ]
        if let tabGroupName {
            result.append(.name(tabGroupName))
        }
        if tabSelection == value {
            result.append(.checked)
        }
        if !isEnabled {
            result.append(.disabled)
        }
        return result
    }
}
