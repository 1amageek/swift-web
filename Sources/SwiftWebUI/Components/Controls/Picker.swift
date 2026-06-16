import SwiftHTML

public struct Picker<Content: HTML>: WebUIAttributeComponent {
    private let title: String
    private let selection: Binding<String>
    private let attributes: [HTMLAttribute]
    private let content: Content
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.pickerStyle) private var pickerStyle

    public init(
        _ title: String,
        selection: Binding<String>,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        if pickerStyle.usesRadioGroup {
            radioGroupField
        } else {
            menuField
        }
    }

    @HTMLBuilder
    private var menuField: some HTML {
        Element("label", attributes: [.class("swui-picker-field \(LayoutClass.fillHorizontal)")]) {
            span(.class("swui-field-label")) {
                title
            }
            // The picker composes the shared thin material for its fill and
            // backdrop blur. `<select>` is a replaced element, so the `::before`
            // rim/refraction overlay does not paint here, but the fill and blur
            // still apply. The raised surface stays an opaque tint.
            Element(
                "select",
                attributes: mergedAttributes(
                    class: "swui-picker \(controlSize.className) \(MaterialClass.material) \(MaterialClass.thin)",
                    styles: .custom("--swui-material-tint", "var(--swui-field-background)"),
                    extra: selectAttributes
                )
            ) {
                content.environment(\.pickerSelection, selection.wrappedValue)
            }
        }
    }

    @HTMLBuilder
    private var radioGroupField: some HTML {
        // Segmented and inline pickers lower to a `role="radiogroup"` of native
        // radio inputs. The segmented variant composes the shared `bar` material;
        // the inline variant is a plain vertical list with no surrounding chrome.
        Element(
            "div",
            attributes: [.class("swui-picker-field \(LayoutClass.fillHorizontal)")]
        ) {
            span(.class("swui-field-label")) {
                title
            }
            Element(
                "div",
                attributes: mergedAttributes(
                    class: radioGroupClass,
                    styles: radioGroupStyles,
                    extra: radioGroupAttributes
                )
            ) {
                content
                    .environment(\.pickerSelection, selection.wrappedValue)
                    .environment(\.pickerGroupName, groupName)
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, selection: selection, attributes: self.attributes + attributes, content: content)
    }

    private init(
        title: String,
        selection: Binding<String>,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
        self.content = content
    }

    private var selectAttributes: [HTMLAttribute] {
        let selection = self.selection
        var result: [HTMLAttribute] = [
            .value(selection),
            .onChange { event in
                selection.wrappedValue = event.value ?? ""
            },
        ]
        if !isEnabled {
            result.append(.disabled)
            result.append(.aria("disabled", "true"))
        }
        result.append(contentsOf: attributes)
        return result
    }

    private var radioGroupClass: String {
        switch pickerStyle {
        case .segmented:
            "swui-picker-segmented \(controlSize.className) \(MaterialClass.material) \(MaterialClass.bar)"
        case .inline:
            "swui-picker-inline \(controlSize.className)"
        case .automatic, .menu:
            ""
        }
    }

    private var radioGroupStyles: Style {
        switch pickerStyle {
        case .segmented:
            .custom("--swui-material-tint", "var(--swui-field-background)")
        case .inline, .automatic, .menu:
            Style()
        }
    }

    // A single delegated change handler on the group container: a child radio's
    // change event bubbles here, and `event.value` carries the fired radio's
    // value, so one handler drives the whole group.
    private var radioGroupAttributes: [HTMLAttribute] {
        let selection = self.selection
        var result: [HTMLAttribute] = [
            HTMLAttribute("role", "radiogroup"),
            .aria("label", title),
            .onChange { event in
                if let value = event.value {
                    selection.wrappedValue = value
                }
            },
        ]
        if !isEnabled {
            result.append(.aria("disabled", "true"))
        }
        result.append(contentsOf: attributes)
        return result
    }

    // A stable radio-group `name` derived from the title so the options are
    // mutually exclusive natively. Segmented/inline pickers on one page should
    // use distinct titles to avoid sharing a group.
    private var groupName: String {
        let sanitized = String(title.lowercased().map { character in
            character.isLetter || character.isNumber ? character : "-"
        })
        return "swui-picker-\(sanitized)"
    }
}
