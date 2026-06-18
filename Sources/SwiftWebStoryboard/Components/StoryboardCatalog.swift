import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Style mapping

private func catalogStyleSystem(for id: String) -> StyleSystem {
    switch id {
    case "material":
        return .material
    case "liquid-glass":
        return .liquidGlass
    default:
        return .swiftWeb
    }
}

// MARK: - Registry

/// One component entry. `id` is the selection key shared by the sidebar, the
/// detail router, and the inspector. `code` and `summary` are the metadata the
/// inspector shows; the live demo is matched to `id` in the detail router.
public struct CatalogItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let code: String
    public let summary: String

    public init(id: String, name: String, code: String, summary: String) {
        self.id = id
        self.name = name
        self.code = code
        self.summary = summary
    }
}

/// A sidebar group of components.
public struct CatalogCategory: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let items: [CatalogItem]

    public init(id: String, title: String, items: [CatalogItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// The catalog model. It drives the sidebar list and the inspector metadata;
/// `CatalogDetail` maps a selection id to its live demo.
public let catalogCategories: [CatalogCategory] = [
    CatalogCategory(id: "foundations", title: "Foundations", items: [
        CatalogItem(id: "typography", name: "Typography", code: "Heading(_:level:) · Text(_:tone:)", summary: "Headings and text tones resolve to theme tokens."),
        CatalogItem(id: "textblock", name: "TextBlock", code: "TextBlock(_:tone:)", summary: "Paragraph text with the same tone contract as Text, rendered as a block-level paragraph."),
        CatalogItem(id: "color", name: "Color & tint", code: ".tint(.accent)", summary: "tint(_:) recolors a control's accent; semantic and custom colors are available."),
        CatalogItem(id: "materials", name: "Materials", code: ".background(.regularMaterial, in:)", summary: "One recipe behind every surface; a level only scales the fill. Liquid Glass adds blur, a specular rim, and refraction."),
        CatalogItem(id: "glass", name: "Glass", code: ".glassEffect(.regular, in:)", summary: "glassEffect(in:) frosts any surface; GlassEffectContainer shares one glass context across siblings."),
    ]),
    CatalogCategory(id: "buttons", title: "Buttons & actions", items: [
        CatalogItem(id: "button", name: "Button", code: "Button(_:prominence:)", summary: "Prominence sets the visual weight."),
        CatalogItem(id: "button-styles", name: "Button styles", code: ".buttonStyle(.glass)", summary: "Glass styles read as Liquid Glass under that style system and degrade to a solid surface elsewhere."),
        CatalogItem(id: "control-sizes", name: "Control sizes", code: ".controlSize(.large)", summary: "controlSize(_:) scales padding and type together."),
        CatalogItem(id: "button-states", name: "Tint & disabled", code: ".disabled()", summary: "tint(_:) recolors; disabled() dims and blocks interaction."),
        CatalogItem(id: "links", name: "Links", code: "ButtonLink(_:href:) · Link(_:href:)", summary: "ButtonLink looks like a button; Link is plain inline navigation."),
    ]),
    CatalogCategory(id: "inputs", title: "Inputs & controls", items: [
        CatalogItem(id: "textfield", name: "TextField", code: "TextField(_:text:)", summary: "Text entry with input type, validation, and content-type hints."),
        CatalogItem(id: "securefield", name: "SecureField", code: "SecureField(_:text:)", summary: "Masked entry for secrets."),
        CatalogItem(id: "texteditor", name: "TextEditor", code: "TextEditor(text:)", summary: "Multi-line text entry that composes the thin material."),
        CatalogItem(id: "toggle", name: "Toggle", code: "Toggle(_:isOn:)", summary: "A boolean switch; the track composes the unified material."),
        CatalogItem(id: "slider", name: "Slider", code: "Slider(value:in:step:)", summary: "A continuous value across a range with an optional step."),
        CatalogItem(id: "stepper", name: "Stepper", code: "Stepper(_:value:in:)", summary: "Increment or decrement a discrete value within bounds."),
        CatalogItem(id: "datepicker", name: "DatePicker", code: "DatePicker(_:selection:displayedComponents:)", summary: "displayedComponents selects date, time, or both."),
        CatalogItem(id: "colorpicker", name: "ColorPicker", code: "ColorPicker(_:selection:)", summary: "A native color well bound to a hex string."),
        CatalogItem(id: "form", name: "Form", code: "Form(action:method:)", summary: "A Form posts to an action; SubmitButtons carry name/value."),
    ]),
    CatalogCategory(id: "pickers", title: "Pickers & menus", items: [
        CatalogItem(id: "picker", name: "Picker", code: ".pickerStyle(.segmented)", summary: "pickerStyle(_:) chooses dropdown, segmented, inline, or menu."),
        CatalogItem(id: "menu", name: "Menu", code: "Menu(_:content:)", summary: "A pull-down list of actions disclosed on demand."),
    ]),
    CatalogCategory(id: "containers", title: "Containers", items: [
        CatalogItem(id: "card", name: "Card", code: "Card { }", summary: "The primary surface; composes the regular material."),
        CatalogItem(id: "toolbar", name: "Toolbar", code: "Toolbar { }", summary: "A horizontal command surface that composes the bar material and fills its container."),
        CatalogItem(id: "badge", name: "Badge", code: "Badge(_:)", summary: "A compact status pill that hugs its label."),
        CatalogItem(id: "valuedisplay", name: "ValueDisplay", code: "ValueDisplay(label:value:)", summary: "A labeled readout for a single metric."),
        CatalogItem(id: "list", name: "List", code: "List { ListRow { } }", summary: "Grouped rows that fill their container; Spacer splits leading and trailing."),
        CatalogItem(id: "section", name: "Section", code: "Section(_:footer:)", summary: "A titled group with an optional footer."),
        CatalogItem(id: "disclosuregroup", name: "DisclosureGroup", code: "DisclosureGroup(_:isExpanded:)", summary: "An expandable region; composes the regular material like Card."),
        CatalogItem(id: "grid", name: "Grid", code: "Grid(minColumnWidth:spacing:)", summary: "A responsive grid that wraps at a minimum column width."),
        CatalogItem(id: "lazy", name: "Lazy stacks & grids", code: "LazyVStack · LazyVGrid(columns:)", summary: "Lazy containers mark their scroll axis for large collections."),
        CatalogItem(id: "scrollview", name: "ScrollView", code: "ScrollView(.vertical)", summary: "Clips overflow on its axis and scrolls within a fixed frame."),
    ]),
    CatalogCategory(id: "status", title: "Status", items: [
        CatalogItem(id: "progressview", name: "ProgressView", code: "ProgressView(_:value:)", summary: "A determinate bar with a value, or an indeterminate spinner without one."),
        CatalogItem(id: "gauge", name: "Gauge", code: "Gauge(value:label:)", summary: "A compact readout of a value within a range."),
    ]),
    CatalogCategory(id: "navigation", title: "Navigation & tabs", items: [
        CatalogItem(id: "navigationstack", name: "NavigationStack", code: "NavigationStack { NavigationLink }", summary: "A single-column stack; NavigationLink pushes a destination."),
        CatalogItem(id: "navigationlink", name: "NavigationLink", code: "NavigationLink(_:href:)", summary: "A semantic navigation row or inline control that points to another location."),
        CatalogItem(id: "tabview", name: "TabView", code: "TabView(selection:) { Tab }", summary: "Switches panels; the tab bar composes interactive glass."),
        CatalogItem(id: "searchable", name: "Searchable", code: ".searchable(text:)", summary: "Adds a search field bound to a query over a collection."),
    ]),
    CatalogCategory(id: "presentation", title: "Presentation", items: [
        CatalogItem(id: "alert", name: "Alert & dialog", code: ".alert(_:isPresented:)", summary: "alert(_:isPresented:) and confirmationDialog(...) interrupt for a decision."),
        CatalogItem(id: "sheet", name: "Sheet & popover", code: ".sheet(isPresented:)", summary: "sheet(isPresented:) lifts a panel; popover(isPresented:) anchors to its source."),
    ]),
    CatalogCategory(id: "layout", title: "Layout", items: [
        CatalogItem(id: "stacks", name: "Stacks", code: "VStack · HStack · ZStack", summary: "VStack and HStack arrange along an axis; ZStack overlays."),
        CatalogItem(id: "spacer", name: "Spacer & Divider", code: "Spacer() · Divider()", summary: "Spacer pushes siblings apart; Divider draws a hairline rule."),
        CatalogItem(id: "hug-fill", name: "Hug vs fill", code: ".fixedSize() · .frame(maxWidth: .infinity)", summary: "fixedSize() hugs the content; frame(maxWidth: .infinity) fills the column."),
    ]),
    CatalogCategory(id: "media", title: "Media", items: [
        CatalogItem(id: "image", name: "Image", code: "Image(systemName:)", summary: "An SF Symbol name renders as a symbol span."),
        CatalogItem(id: "label", name: "Label", code: "Label(_:systemImage:)", summary: "Pairs an icon with a title."),
    ]),
]

public let catalogDefaultSelection = "typography"

private func catalogItem(for id: String) -> CatalogItem? {
    for category in catalogCategories {
        for item in category.items where item.id == id {
            return item
        }
    }
    return nil
}

private func catalogCategory(for itemID: String) -> CatalogCategory? {
    for category in catalogCategories where category.items.contains(where: { $0.id == itemID }) {
        return category
    }
    return nil
}

// MARK: - Detail metadata

struct CatalogProperty: Identifiable, Sendable {
    let id: String
    let name: String
    let acceptedValues: String
    let summary: String

    init(_ name: String, values: String, summary: String) {
        self.id = name
        self.name = name
        self.acceptedValues = values
        self.summary = summary
    }
}

struct CatalogDetailSpec: Sendable {
    let overview: String
    let properties: [CatalogProperty]
    let snippet: String
}

func catalogDetailSpec(for item: CatalogItem) -> CatalogDetailSpec {
    CatalogDetailSpec(
        overview: catalogOverview(for: item),
        properties: catalogProperties(for: item.id),
        snippet: catalogSnippet(for: item.id)
    )
}

private func catalogOverview(for item: CatalogItem) -> String {
    "\(item.summary) The live preview above is the canonical behavior for this Storyboard entry."
}

private func catalogProperties(for id: String) -> [CatalogProperty] {
    switch id {
    case "typography":
        return [
            CatalogProperty("level", values: ".page / .section / .subsection", summary: "Controls Heading scale and semantic heading rank."),
            CatalogProperty("as", values: ".p / .small / .strong / .code / custom tag", summary: "Switches Text's rendered element while keeping SwiftWebUI styling."),
            CatalogProperty("tone", values: ".normal / .muted", summary: "Maps copy to primary or secondary theme tokens."),
        ]
    case "textblock":
        return [
            CatalogProperty("text", values: "String", summary: "Paragraph content rendered as one block-level element."),
            CatalogProperty("tone", values: ".normal / .muted", summary: "Maps the paragraph to primary or secondary text tokens."),
            CatalogProperty("attributes", values: "HTMLAttribute...", summary: "Adds semantic attributes without leaving SwiftWebUI."),
        ]
    case "color":
        return [
            CatalogProperty("tint", values: ".accent / .danger / .css(String)", summary: "Sets the component accent without changing the global theme."),
            CatalogProperty("foregroundStyle", values: "semantic or CSS color", summary: "Overrides foreground color for a scoped component."),
            CatalogProperty("background", values: "semantic token or CSS color", summary: "Applies a local fill when a component needs a custom surface."),
        ]
    case "materials":
        return [
            CatalogProperty("material", values: ".ultraThinMaterial ... .bar", summary: "Selects the surface recipe resolved by the active StyleSystem."),
            CatalogProperty("shape", values: ".rect(cornerRadius:) / .capsule", summary: "Clips and outlines the material surface."),
            CatalogProperty("styleSystem", values: ".swiftWeb / .material / .liquidGlass", summary: "Changes how the same material contract is painted."),
        ]
    case "glass":
        return [
            CatalogProperty("effect", values: ".regular", summary: "Defines the glass recipe attached to the surface."),
            CatalogProperty("shape", values: ".rect(cornerRadius:) / .capsule", summary: "Controls clipping and hit-area geometry."),
            CatalogProperty("tint / interactive", values: ".tint(String) / .interactive()", summary: "Adds color and interactive response to the glass surface."),
        ]
    case "button":
        return [
            CatalogProperty("title / content", values: "String or @HTMLBuilder", summary: "Supplies visible button content."),
            CatalogProperty("prominence", values: ".primary / .secondary", summary: "Controls visual weight."),
            CatalogProperty("action", values: "closure / Action", summary: "Runs client-side state changes or posts to a server action."),
        ]
    case "button-styles":
        return [
            CatalogProperty("buttonStyle", values: ".automatic / .plain / .glass / .glassProminent", summary: "Switches the button recipe independently from its action."),
            CatalogProperty("prominence", values: ".primary / .secondary", summary: "Combines with style to set emphasis."),
            CatalogProperty("styleSystem", values: "environment value", summary: "Resolves glass styles differently per style system."),
        ]
    case "control-sizes":
        return [
            CatalogProperty("controlSize", values: ".mini / .small / .regular / .large", summary: "Scales padding and font size together."),
            CatalogProperty("prominence", values: ".primary / .secondary", summary: "Keeps hierarchy stable across sizes."),
            CatalogProperty("frame", values: "width / maxWidth / alignment", summary: "Controls whether the control hugs content or fills a row."),
        ]
    case "button-states":
        return [
            CatalogProperty("disabled", values: "Bool", summary: "Blocks interaction and applies disabled styling."),
            CatalogProperty("tint", values: "semantic or CSS color", summary: "Recolors enabled controls."),
            CatalogProperty("name / value", values: "String", summary: "Submitted payload for form-backed buttons."),
        ]
    case "links":
        return [
            CatalogProperty("href", values: "URL string", summary: "Navigation target."),
            CatalogProperty("prominence", values: ".primary / .secondary", summary: "ButtonLink only; chooses button weight."),
            CatalogProperty("content", values: "String or builder", summary: "Visible label."),
        ]
    case "textfield":
        return [
            CatalogProperty("text", values: "Binding<String>", summary: "Two-way value binding."),
            CatalogProperty("attributes", values: ".type / .required / .placeholder", summary: "HTML input hints exposed as SwiftHTML attributes."),
            CatalogProperty("textContentType", values: "TextContentType", summary: "Autofill and semantic input hints."),
        ]
    case "securefield":
        return [
            CatalogProperty("text", values: "Binding<String>", summary: "Two-way secret value binding."),
            CatalogProperty("prompt", values: "String", summary: "Visible placeholder or label."),
            CatalogProperty("textContentType", values: ".password / .newPassword", summary: "Autofill semantics for secret fields."),
        ]
    case "texteditor":
        return [
            CatalogProperty("text", values: "Binding<String>", summary: "Multi-line text binding."),
            CatalogProperty("frame", values: "height / minHeight / maxHeight", summary: "Sets the editing area size."),
            CatalogProperty("disabled", values: "Bool", summary: "Prevents editing while preserving content."),
        ]
    case "toggle":
        return [
            CatalogProperty("isOn", values: "Binding<Bool>", summary: "Boolean state owned by the component or page."),
            CatalogProperty("label", values: "String or builder", summary: "Visible control label."),
            CatalogProperty("disabled", values: "Bool", summary: "Locks the current value."),
        ]
    case "slider":
        return [
            CatalogProperty("value", values: "Binding<Double>", summary: "Current numeric value."),
            CatalogProperty("range", values: "ClosedRange<Double>", summary: "Minimum and maximum values."),
            CatalogProperty("step", values: "Double?", summary: "Optional snapping interval."),
        ]
    case "stepper":
        return [
            CatalogProperty("value", values: "Binding<Int>", summary: "Current discrete value."),
            CatalogProperty("range", values: "ClosedRange<Int>", summary: "Allowed lower and upper bounds."),
            CatalogProperty("label", values: "String", summary: "Describes the stepped value."),
        ]
    case "datepicker":
        return [
            CatalogProperty("selection", values: "Binding<Date>", summary: "Selected date/time."),
            CatalogProperty("displayedComponents", values: ".date / .hourAndMinute", summary: "Chooses which native controls are visible."),
            CatalogProperty("label", values: "String", summary: "Accessible field label."),
        ]
    case "colorpicker":
        return [
            CatalogProperty("selection", values: "Binding<String>", summary: "Hex color string."),
            CatalogProperty("label", values: "String", summary: "Accessible color purpose."),
            CatalogProperty("tint", values: "semantic or CSS color", summary: "Styles neighboring actions that consume the picked color."),
        ]
    case "form":
        return [
            CatalogProperty("action", values: "URL string or server action route", summary: "Submit endpoint."),
            CatalogProperty("method", values: ".get / .post", summary: "HTTP method for submission."),
            CatalogProperty("SubmitButton name/value", values: "String", summary: "Distinguishes user intent inside one form."),
        ]
    case "picker":
        return [
            CatalogProperty("selection", values: "Binding<String>", summary: "Selected option value."),
            CatalogProperty("PickerOption", values: "label + value", summary: "Declares each selectable choice."),
            CatalogProperty("pickerStyle", values: ".automatic / .segmented / .inline / .menu", summary: "Changes presentation without changing data binding."),
        ]
    case "menu":
        return [
            CatalogProperty("label", values: "String or builder", summary: "Visible disclosure control."),
            CatalogProperty("content", values: "Button / Link / custom rows", summary: "Actions shown when opened."),
            CatalogProperty("disabled", values: "Bool", summary: "Prevents opening."),
        ]
    case "card":
        return [
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Children grouped onto one surface."),
            CatalogProperty("padding", values: "Space or CSS length", summary: "Controls interior spacing."),
            CatalogProperty("background", values: "Material or CSS", summary: "Changes the surface recipe."),
        ]
    case "toolbar":
        return [
            CatalogProperty("content", values: "Button / Link / Spacer / custom views", summary: "Commands arranged in one horizontal chrome region."),
            CatalogProperty("material", values: ".bar", summary: "Uses the bar material recipe from the active StyleSystem."),
            CatalogProperty("frame", values: "maxWidth / alignment", summary: "Toolbars fill horizontally by default and can be constrained by their parent."),
        ]
    case "badge":
        return [
            CatalogProperty("label", values: "String", summary: "Compact status text."),
            CatalogProperty("tint", values: "semantic or CSS color", summary: "Communicates category or severity."),
            CatalogProperty("fixedSize", values: "modifier", summary: "Keeps the badge hugging its content."),
        ]
    case "valuedisplay":
        return [
            CatalogProperty("label", values: "String", summary: "Metric name."),
            CatalogProperty("value", values: "String / Int / Double", summary: "Primary readout."),
            CatalogProperty("frame", values: "width / maxWidth", summary: "Controls dashboard tile sizing."),
        ]
    case "list":
        return [
            CatalogProperty("rows", values: "ListRow", summary: "Each row can hold leading and trailing content."),
            CatalogProperty("spacing", values: "StyleSystem token", summary: "Resolved by the active style system."),
            CatalogProperty("Spacer", values: "layout child", summary: "Splits row content into leading and trailing regions."),
        ]
    case "section":
        return [
            CatalogProperty("title", values: "String", summary: "Section heading."),
            CatalogProperty("footer", values: "String?", summary: "Optional explanatory copy."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Grouped form or settings content."),
        ]
    case "disclosuregroup":
        return [
            CatalogProperty("title", values: "String", summary: "Disclosure label."),
            CatalogProperty("isExpanded", values: "Binding<Bool> or Bool", summary: "Controls open state."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Revealed content."),
        ]
    case "grid":
        return [
            CatalogProperty("minColumnWidth", values: "CSS length", summary: "Responsive wrapping threshold."),
            CatalogProperty("spacing", values: "Space", summary: "Gap between cells."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Grid cells."),
        ]
    case "lazy":
        return [
            CatalogProperty("axis", values: "LazyVStack / LazyHStack / LazyVGrid / LazyHGrid", summary: "Declares the scroll direction and layout strategy."),
            CatalogProperty("columns / rows", values: "[GridItem]", summary: "Grid track definitions."),
            CatalogProperty("spacing", values: "Space", summary: "Gap between lazy children."),
        ]
    case "scrollview":
        return [
            CatalogProperty("axes", values: ".vertical / .horizontal / both", summary: "Controls overflow direction."),
            CatalogProperty("frame", values: "height / width", summary: "Required when the scroll area should be bounded."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Scrollable children."),
        ]
    case "progressview":
        return [
            CatalogProperty("label", values: "String?", summary: "Accessible progress label."),
            CatalogProperty("value", values: "Double?", summary: "Determinate value; nil renders indeterminate."),
            CatalogProperty("tint", values: "semantic or CSS color", summary: "Progress accent."),
        ]
    case "gauge":
        return [
            CatalogProperty("value", values: "Double", summary: "Current value normalized by the range."),
            CatalogProperty("label", values: "String", summary: "Readout name."),
            CatalogProperty("range", values: "ClosedRange<Double>", summary: "Optional measurement bounds."),
        ]
    case "navigationstack":
        return [
            CatalogProperty("content", values: "NavigationLink / custom content", summary: "Root stack content."),
            CatalogProperty("href", values: "URL string", summary: "Navigation target for links."),
            CatalogProperty("title", values: "modifier", summary: "Declares page or stack title when used in a page."),
        ]
    case "navigationlink":
        return [
            CatalogProperty("label", values: "String or @HTMLBuilder", summary: "Visible navigation content."),
            CatalogProperty("href", values: "URL string", summary: "Destination URL emitted as a semantic anchor."),
            CatalogProperty("attributes", values: "HTMLAttribute...", summary: "Adds target, rel, aria, or data attributes as needed."),
        ]
    case "tabview":
        return [
            CatalogProperty("selection", values: "Binding<String>", summary: "Currently active tab."),
            CatalogProperty("Tab value", values: "String", summary: "Stable identity for each tab."),
            CatalogProperty("systemImage", values: "SF Symbol name", summary: "Optional tab icon."),
        ]
    case "searchable":
        return [
            CatalogProperty("text", values: "Binding<String>", summary: "Search query."),
            CatalogProperty("prompt", values: "String?", summary: "Placeholder text."),
            CatalogProperty("scope", values: "applied content", summary: "The modifier wraps the searchable content."),
        ]
    case "alert":
        return [
            CatalogProperty("isPresented", values: "Binding<Bool>", summary: "Controls presentation."),
            CatalogProperty("actions", values: "Button builder", summary: "Decision buttons."),
            CatalogProperty("message", values: "Text builder", summary: "Additional explanatory copy."),
        ]
    case "sheet":
        return [
            CatalogProperty("isPresented", values: "Binding<Bool>", summary: "Controls visibility."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Presented panel content."),
            CatalogProperty("onDismiss", values: "closure?", summary: "Optional cleanup callback."),
        ]
    case "stacks":
        return [
            CatalogProperty("alignment", values: ".leading / .center / .trailing", summary: "Cross-axis alignment."),
            CatalogProperty("spacing", values: "Space", summary: "Gap between children."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Arranged children."),
        ]
    case "spacer":
        return [
            CatalogProperty("Spacer", values: "flex child", summary: "Consumes remaining main-axis space."),
            CatalogProperty("Divider", values: "horizontal or vertical rule", summary: "Draws a separator."),
            CatalogProperty("frame", values: "length modifiers", summary: "Constrains separators and spacer regions."),
        ]
    case "hug-fill":
        return [
            CatalogProperty("fixedSize", values: "modifier", summary: "Pins the component to intrinsic content size."),
            CatalogProperty("frame(maxWidth:)", values: ".infinity or CSS length", summary: "Lets the component fill available width."),
            CatalogProperty("alignment", values: "Alignment", summary: "Positions content inside the frame."),
        ]
    case "image":
        return [
            CatalogProperty("systemName", values: "SF Symbol name", summary: "Symbol identifier."),
            CatalogProperty("foregroundStyle", values: "semantic or CSS color", summary: "Icon color."),
            CatalogProperty("font", values: "style modifier", summary: "Controls symbol size through text sizing."),
        ]
    case "label":
        return [
            CatalogProperty("title", values: "String", summary: "Visible text."),
            CatalogProperty("systemImage", values: "SF Symbol name", summary: "Leading icon."),
            CatalogProperty("spacing", values: "StyleSystem token", summary: "Resolved icon/text gap."),
        ]
    default:
        return [
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Child content rendered inside the component."),
            CatalogProperty("modifiers", values: "SwiftWebUI modifiers", summary: "Frame, padding, tint, style, and environment can be layered as needed."),
        ]
    }
}

private func catalogSnippet(for id: String) -> String {
    switch id {
    case "typography":
        return """
        VStack(alignment: .leading, spacing: .small) {
            Heading("Page heading", level: .page)
            Heading("Section heading", level: .section)
            Text("Muted secondary copy", tone: .muted)
            Text("inline.code()", as: .code)
        }
        """
    case "textblock":
        return """
        VStack(alignment: .leading, spacing: .small) {
            TextBlock("Paragraph copy for long-form content.")
            TextBlock("Muted paragraph copy for support text.", tone: .muted)
        }
        """
    case "color":
        return """
        HStack(spacing: .small) {
            Button("Accent", prominence: .primary)
                .tint(.accent)
            Button("Danger", prominence: .primary)
                .tint(.danger)
            Button("Custom", prominence: .primary)
                .tint(.css("#22a06b"))
        }
        """
    case "materials":
        return """
        VStack(alignment: .leading, spacing: .medium) {
            Text("Regular material")
                .padding(.all, "16px")
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
            Text("Bar material")
                .padding(.all, "16px")
                .background(.bar, in: .rect(cornerRadius: 16))
        }
        .environment(\\.styleSystem, .liquidGlass)
        """
    case "glass":
        return """
        GlassEffectContainer(spacing: .medium) {
            Text("Regular glass")
                .padding(.all, "12px 18px")
                .glassEffect(.regular, in: .capsule)
            Text("Tinted")
                .padding(.all, "12px 18px")
                .glassEffect(.regular.tint("var(--swui-accent)").interactive(), in: .capsule)
        }
        """
    case "button":
        return """
        HStack(spacing: .small) {
            Button("Primary", prominence: .primary) {
                count += 1
            }
            Button("Secondary") {
                count -= 1
            }
        }
        """
    case "button-styles":
        return """
        HStack(spacing: .small) {
            Button("Glass", prominence: .primary)
                .buttonStyle(.glass)
            Button("Glass prominent", prominence: .primary)
                .buttonStyle(.glassProminent)
            Button("Plain")
                .buttonStyle(.plain)
        }
        """
    case "control-sizes":
        return """
        HStack(spacing: .small) {
            Button("Mini").controlSize(.mini)
            Button("Small").controlSize(.small)
            Button("Regular").controlSize(.regular)
            Button("Large").controlSize(.large)
        }
        """
    case "button-states":
        return """
        HStack(spacing: .small) {
            Button("Enabled", prominence: .primary)
            Button("Disabled", prominence: .primary)
                .disabled()
            SubmitButton("Submit")
                .disabled()
        }
        """
    case "links":
        return """
        HStack(spacing: .small) {
            ButtonLink("Primary link", href: "/docs", prominence: .primary)
            ButtonLink("Secondary link", href: "/docs", prominence: .secondary)
            Link("Inline anchor", href: "/docs")
        }
        """
    case "textfield":
        return """
        VStack(alignment: .leading, spacing: .small) {
            TextField("Name", text: $name)
            TextField("Email", text: $email, .type(.email), .required)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .submitLabel(.go)
        }
        """
    case "securefield":
        return """
        SecureField("Secret", text: $secret)
            .textContentType(.password)
        """
    case "texteditor":
        return """
        TextEditor(text: $notes)
            .frame(minHeight: "120px", alignment: .topLeading)
        """
    case "toggle":
        return """
        Toggle("Enabled", isOn: $enabled)
        """
    case "slider":
        return """
        Slider(value: $volume, in: 0...1, step: 0.05)
        """
    case "stepper":
        return """
        VStack(alignment: .leading, spacing: .small) {
            Stepper("Density", value: $density, in: 0...8)
            ValueDisplay(label: "Density", value: density)
        }
        """
    case "datepicker":
        return """
        VStack(alignment: .leading, spacing: .small) {
            DatePicker("Due date", selection: $due)
            DatePicker(
                "Starts at",
                selection: $due,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
        """
    case "colorpicker":
        return """
        ColorPicker("Accent", selection: $accent)
        """
    case "form":
        return """
        Form(action: "/subscribe", method: .post) {
            VStack(alignment: .leading, spacing: .medium) {
                Label("Email address", systemImage: "envelope")
                HStack(spacing: .small) {
                    SubmitButton("Subscribe", prominence: .primary)
                        .name("intent")
                        .value("subscribe")
                    SubmitButton("Unsubscribe")
                        .name("intent")
                        .value("unsubscribe")
                }
            }
        }
        """
    case "picker":
        return """
        Picker("View", selection: $segment) {
            PickerOption("List", value: "list")
            PickerOption("Grid", value: "grid")
            PickerOption("Columns", value: "columns")
        }
        .pickerStyle(.segmented)
        """
    case "menu":
        return """
        Menu("Options") {
            Button("Duplicate") {}
            Button("Move...") {}
            Button("Delete") {}
        }
        """
    case "card":
        return """
        Card {
            VStack(alignment: .leading, spacing: .small) {
                Heading("Card title", level: .subsection)
                Text("Cards group related content.", tone: .muted)
            }
        }
        """
    case "toolbar":
        return """
        Toolbar {
            Button("Back")
            Spacer()
            Button("Save", prominence: .primary)
        }
        """
    case "badge":
        return """
        HStack(spacing: .small) {
            Badge("Default")
            Badge("Ready")
            Badge("Beta")
        }
        """
    case "valuedisplay":
        return """
        HStack(spacing: .medium) {
            ValueDisplay(label: "Score", value: 42)
            ValueDisplay(label: "Streak", value: 7)
            ValueDisplay(label: "Grade", value: "A+")
        }
        """
    case "list":
        return """
        List {
            ListRow {
                Text("Wi-Fi")
                Spacer()
                Badge("On")
            }
            ListRow {
                Text("Bluetooth")
                Spacer()
                Text("Off", tone: .muted)
            }
        }
        """
    case "section":
        return """
        Section("Account", footer: "Signed in as ada@example.com") {
            VStack(alignment: .leading, spacing: .small) {
                Text("Profile")
                Text("Security")
                Text("Notifications")
            }
        }
        """
    case "disclosuregroup":
        return """
        DisclosureGroup("Advanced options", isExpanded: true) {
            VStack(alignment: .leading, spacing: .small) {
                Text("Nested content reveals when expanded.", tone: .muted)
                Label("Verbose logging", systemImage: "doc.text")
            }
        }
        """
    case "grid":
        return """
        Grid(minColumnWidth: "120px", spacing: .small) {
            Badge("Cell 1")
            Badge("Cell 2")
            Badge("Cell 3")
            Badge("Cell 4")
        }
        """
    case "lazy":
        return """
        Grid(minColumnWidth: "220px", spacing: .large) {
            LazyVStack(alignment: .leading, spacing: .small) {
                Badge("Row 1")
                Badge("Row 2")
            }
            LazyHStack(spacing: .small) {
                Badge("A")
                Badge("B")
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .small) {
                Badge("1")
                Badge("2")
            }
            LazyHGrid(rows: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: .small) {
                Badge("1")
                Badge("2")
            }
        }
        """
    case "scrollview":
        return """
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: .small) {
                ForEach(items) { item in
                    Badge(item.title)
                }
            }
        }
        .frame(maxWidth: .infinity, height: "160px")
        """
    case "progressview":
        return """
        VStack(alignment: .leading, spacing: .small) {
            ProgressView("Uploading", value: 0.35)
            ProgressView("Rendering", value: 0.7)
            ProgressView("Loading")
        }
        """
    case "gauge":
        return """
        VStack(alignment: .leading, spacing: .small) {
            Gauge(value: 0.25, label: "Disk")
            Gauge(value: 0.62, label: "CPU")
            Gauge(value: 0.9, label: "Memory")
        }
        """
    case "navigationstack":
        return """
        NavigationStack {
            VStack(alignment: .leading, spacing: .small) {
                NavigationLink("Overview", href: "#")
                NavigationLink("Components", href: "#components")
                NavigationLink("Tokens", href: "#tokens")
            }
        }
        """
    case "navigationlink":
        return """
        VStack(alignment: .leading, spacing: .small) {
            NavigationLink("Overview", href: "#overview")
            NavigationLink(href: "#settings") {
                Label("Settings", systemImage: "gear")
            }
        }
        """
    case "tabview":
        return """
        TabView(selection: $tab) {
            Tab("Summary", systemImage: "doc.text", value: "summary") {
                Text("Summary panel content.", tone: .muted)
            }
            Tab("Settings", systemImage: "gear", value: "settings") {
                Text("Settings panel content.", tone: .muted)
            }
        }
        """
    case "searchable":
        return """
        List {
            ListRow { Text("Inbox") }
            ListRow { Text("Drafts") }
            ListRow { Text("Sent") }
        }
        .searchable(text: $query, prompt: "Search folders")
        """
    case "alert":
        return """
        Button("Show alert") {
            showsAlert = true
        }
        .alert("Delete this draft?", isPresented: $showsAlert) {
            Button("Delete", action: Action.post("/delete"))
        } message: {
            Text("This action cannot be undone.")
        }
        """
    case "sheet":
        return """
        Button("Show sheet") {
            showsSheet = true
        }
        .sheet(isPresented: $showsSheet) {
            VStack(alignment: .leading, spacing: .medium) {
                Heading("Sheet", level: .section)
                Text("A sheet lifts a panel to the top layer.", tone: .muted)
                Button("Done") { showsSheet = false }
            }
        }
        """
    case "stacks":
        return """
        Grid(minColumnWidth: "180px", spacing: .large) {
            VStack(alignment: .leading, spacing: .small) {
                Badge("Top")
                Badge("Middle")
                Badge("Bottom")
            }
            HStack(spacing: .small) {
                Badge("A")
                Badge("B")
                Badge("C")
            }
        }
        """
    case "spacer":
        return """
        VStack(alignment: .leading, spacing: .small) {
            HStack(spacing: .small) {
                Badge("leading")
                Spacer()
                Badge("trailing")
            }
            Divider()
        }
        """
    case "hug-fill":
        return """
        VStack(alignment: .leading, spacing: .small) {
            Badge("fixedSize()")
                .fixedSize()
            Badge("frame(maxWidth: .infinity)")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        """
    case "image":
        return """
        HStack(spacing: .medium) {
            Image(systemName: "star.fill")
            Image(systemName: "bell.badge")
            Image(systemName: "gearshape")
        }
        """
    case "label":
        return """
        HStack(spacing: .large) {
            Label("Verified", systemImage: "checkmark.seal.fill")
            Label("Favorite", systemImage: "heart.fill")
            Label("Pinned", systemImage: "pin.fill")
        }
        """
    default:
        return """
        VStack(alignment: .leading, spacing: .small) {
            Text("Component content")
        }
        """
    }
}

// MARK: - Shells

/// Inline monospace chip naming the call site of the entry's component.
struct CatalogCodeChip: Component {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some HTML {
        Text(text, as: .code)
            .padding(.all, "2px 8px")
            .background("var(--swui-surface-raised)")
            .cornerRadius("6px")
            .style {
                .border("1px solid var(--swui-border)")
                .fontFamily("var(--swui-mono-font-family)")
                .fontSize("0.82em")
            }
    }
}

/// A larger monospace block for the code that reproduces the selected preview.
struct CatalogCodeBlock: Component {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some HTML {
        Text(text, as: .pre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.all, "16px")
            .background("color-mix(in srgb, var(--swui-surface-raised) 92%, var(--swui-accent))")
            .cornerRadius("12px")
            .style {
                .border("1px solid var(--swui-border)")
                .fontFamily("var(--swui-mono-font-family)")
                .fontSize("0.86em")
                .lineHeight("1.55")
                .custom("overflow-x", "auto")
                .custom("white-space", "pre-wrap")
                .custom("tab-size", "4")
            }
    }
}

/// Section chrome for the center detail pane. It mirrors documentation systems
/// that separate usage, variants, and API reference without turning the preview
/// into a nested card.
struct CatalogDetailSection<Content: HTML>: Component {
    let title: String
    let caption: String
    let content: Content

    init(_ title: String, caption: String, @HTMLBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .small) {
            VStack(alignment: .leading, spacing: .xsmall) {
                Heading(title, level: .subsection)
                Text(caption, tone: .muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact prop-reference table for the selected component.
struct CatalogPropertyPanel: Component {
    let properties: [CatalogProperty]

    var body: some HTML {
        VStack(alignment: .leading, spacing: Space.none) {
            HStack(spacing: .medium) {
                Text("Property", as: .small, tone: .muted)
                    .frame(width: "148px", alignment: .leading)
                Text("Accepted values", as: .small, tone: .muted)
                    .frame(width: "220px", alignment: .leading)
                Text("Behavior", as: .small, tone: .muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.all, "10px 14px")
            .style {
                .custom("border-bottom", "1px solid var(--swui-border)")
                .fontWeight("650")
            }

            ForEach(properties) { property in
                CatalogPropertyRow(property: property)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background("var(--swui-surface)")
        .cornerRadius("12px")
        .style {
            .border("1px solid var(--swui-border)")
            .custom("overflow", "hidden")
        }
    }
}

struct CatalogPropertyRow: Component {
    let property: CatalogProperty

    var body: some HTML {
        HStack(alignment: .top, spacing: .medium) {
            Text(property.name, as: .strong)
                .frame(width: "148px", alignment: .leading)
            CatalogCodeChip(property.acceptedValues)
                .frame(width: "220px", alignment: .leading)
            Text(property.summary, tone: .muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.all, "12px 14px")
        .style {
            .custom("border-bottom", "1px solid color-mix(in srgb, var(--swui-border) 70%, transparent)")
        }
    }
}

/// A captioned slot inside a demo, used to label a single variant.
struct CatalogVariant<Content: HTML>: Component {
    let label: String
    let content: Content

    init(_ label: String, @HTMLBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            Text(label, as: .small, tone: .muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A vivid backdrop so a material/glass surface's backdrop blur and refraction
/// read. The gradient is the stage's own background; children blur it through
/// `backdrop-filter` when the style system is Liquid Glass.
struct CatalogGlassStage<Content: HTML>: Component {
    let content: Content
    init(@HTMLBuilder content: () -> Content) { self.content = content() }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .medium) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "20px")
        .cornerRadius("16px")
        .style {
            .background("radial-gradient(440px 220px at 12% 16%, #ff7a7a, transparent 62%), radial-gradient(460px 240px at 88% 18%, #5b8cff, transparent 62%), radial-gradient(560px 280px at 50% 120%, #2dd4a7, transparent 60%), #0f172a")
            .border("1px solid var(--swui-border)")
        }
    }
}

/// A labeled panel filled with a material level via `.background(_:in:)`.
struct CatalogMaterialSwatch: Component {
    let title: String
    let code: String
    let material: Material

    init(_ title: String, code: String, material: Material) {
        self.title = title
        self.code = code
        self.material = material
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            Text(title, as: .strong)
            Text(code, as: .small, tone: .muted)
        }
        .padding(.all, "16px")
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(material, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Chrome: top bar

/// The sticky global control bar spanning all three panes. The theme and
/// style-system controls drive the catalog's @State; the enclosing scope
/// re-applies `.environment` on every change, so the whole catalog rethemes
/// live. The bar composes the `.bar` material, dogfooding the style system it
/// switches.
struct CatalogTopBar: Component {
    let theme: Binding<Theme>
    let styleID: Binding<String>

    var body: some HTML {
        HStack(spacing: .large) {
            HStack(spacing: .small) {
                Badge("SwiftWebUI")
                Text("Component Storyboard", as: .strong)
            }

            Spacer()

            HStack(spacing: .large) {
                HStack(spacing: .xsmall) {
                    Text("Appearance", as: .small, tone: .muted)
                    ThemeSwitcher(selection: theme, themes: [.light, .dark, .system])
                }
                HStack(spacing: .xsmall) {
                    Text("Style", as: .small, tone: .muted)
                    Picker("Style System", selection: styleID) {
                        PickerOption("SwiftWeb", value: "swift-web")
                        PickerOption("Material", value: "material")
                        PickerOption("Liquid Glass", value: "liquid-glass")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "12px 20px")
        .background(.bar, in: .rect(cornerRadius: 0))
        .style {
            .custom("position", "sticky")
            .custom("top", "0")
            .custom("z-index", "40")
            .custom("border-bottom", "1px solid var(--swui-border)")
        }
    }
}

// MARK: - Chrome: sidebar

/// The component picker. Categories are headings; each item is a button that
/// sets the selection @State, re-rendering the detail and inspector.
struct CatalogSidebar: Component {
    let selection: Binding<String>

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            ForEach(catalogCategories) { category in
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text(category.title, as: .small, tone: .muted)
                        .style {
                            .custom("text-transform", "uppercase")
                            .custom("letter-spacing", "0.04em")
                            .fontWeight("600")
                        }
                    ForEach(category.items) { item in
                        CatalogSidebarRow(item: item, selection: selection)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: "168px", alignment: .leading)
        .padding(.all, "18px 14px")
        .style {
            .custom("flex", "0 0 168px")
            .height("100%")
            .custom("overflow-y", "auto")
            .custom("border-right", "1px solid var(--swui-border)")
        }
    }
}

/// One sidebar row: a plain button whose selected state tints the label and
/// raises a subtle accent background.
struct CatalogSidebarRow: Component {
    let item: CatalogItem
    let selection: Binding<String>

    var body: some HTML {
        Button(action: { selection.wrappedValue = item.id }) {
            Text(item.name)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "6px 10px")
        .background(selection.wrappedValue == item.id ? "color-mix(in srgb, var(--swui-accent) 14%, transparent)" : "transparent")
        .cornerRadius("8px")
        .style {
            .custom("color", selection.wrappedValue == item.id ? "var(--swui-accent)" : "var(--swui-text)")
            .custom("justify-content", "flex-start")
            .custom("text-align", "left")
            .fontWeight(selection.wrappedValue == item.id ? "600" : "450")
            .fontSize("0.9em")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chrome: inspector

/// The right pane. It shows the selected component's API signature and summary,
/// then the sibling components in the same section for quick context.
struct CatalogInspector: Component {
    let selection: String

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            inspectorMetadata()
            inspectorSection()
        }
        .frame(width: "200px", alignment: .leading)
        .padding(.all, "20px 18px")
        .style {
            .custom("flex", "0 0 200px")
            .height("100%")
            .custom("overflow-y", "auto")
            .custom("border-left", "1px solid var(--swui-border)")
        }
    }

    @HTMLBuilder
    private func inspectorMetadata() -> some HTML {
        if let item = catalogItem(for: selection) {
            VStack(alignment: .leading, spacing: .large) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("API", as: .small, tone: .muted)
                    CatalogCodeChip(item.code)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Summary", as: .small, tone: .muted)
                    Text(item.summary, tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func inspectorSection() -> some HTML {
        if let category = catalogCategory(for: selection) {
            VStack(alignment: .leading, spacing: .xsmall) {
                Text("In this section", as: .small, tone: .muted)
                ForEach(category.items) { item in
                    inspectorSectionRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func inspectorSectionRow(_ item: CatalogItem) -> some HTML {
        if item.id == selection {
            Text(item.name, as: .strong)
        } else {
            Text(item.name, tone: .muted)
        }
    }
}

// MARK: - Detail router

/// The center pane. A registry-driven header names the component; the demo is
/// routed by category to keep each switch small, then by component id.
struct CatalogDetail: Component {
    let selection: String
    let name: Binding<String>
    let email: Binding<String>
    let secret: Binding<String>
    let notes: Binding<String>
    let enabled: Binding<Bool>
    let volume: Binding<Double>
    let density: Binding<Int>
    let due: Binding<Date>
    let accent: Binding<String>
    let pick: Binding<String>
    let segment: Binding<String>
    let scope: Binding<String>
    let menuPick: Binding<String>
    let tab: Binding<String>
    let query: Binding<String>
    let showsAlert: Binding<Bool>
    let showsConfirmation: Binding<Bool>
    let showsSheet: Binding<Bool>
    let showsPopover: Binding<Bool>

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            if let item = catalogItem(for: selection) {
                let spec = catalogDetailSpec(for: item)
                detailHeader(item: item, spec: spec)

                CatalogDetailSection(
                    "Live preview",
                    caption: "Interactive rendering of the selected component under the current theme and style system."
                ) {
                    Card {
                        VStack(alignment: .leading, spacing: .medium) {
                            detailDemo()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CatalogDetailSection(
                    "Adjustable properties",
                    caption: "Primary inputs, modifiers, and bindings that change this component's behavior."
                ) {
                    CatalogPropertyPanel(properties: spec.properties)
                }

                CatalogDetailSection(
                    "Swift snippet",
                    caption: "A minimal SwiftWebUI example that produces the preview pattern."
                ) {
                    CatalogCodeBlock(spec.snippet)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "28px 32px")
        .style {
            .height("100%")
            .custom("min-width", "0")
            .custom("overflow-y", "auto")
        }
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            Heading(item.name, level: .page)
            Text(spec.overview, tone: .muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: .small) {
                CatalogCodeChip(item.code)
                if let category = catalogCategory(for: item.id) {
                    Badge(category.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func detailDemo() -> some HTML {
        switch catalogCategory(for: selection)?.id ?? "foundations" {
        case "buttons":
            ButtonsDetail(selection: selection)
        case "inputs":
            InputsDetail(
                selection: selection,
                name: name,
                email: email,
                secret: secret,
                notes: notes,
                enabled: enabled,
                volume: volume,
                density: density,
                due: due,
                accent: accent
            )
        case "pickers":
            PickersDetail(selection: selection, pick: pick, segment: segment, scope: scope, menuPick: menuPick)
        case "containers":
            ContainersDetail(selection: selection)
        case "status":
            StatusDetail(selection: selection)
        case "navigation":
            NavigationDetail(selection: selection, tab: tab, query: query)
        case "presentation":
            PresentationDetail(
                selection: selection,
                showsAlert: showsAlert,
                showsConfirmation: showsConfirmation,
                showsSheet: showsSheet,
                showsPopover: showsPopover
            )
        case "layout":
            LayoutDetail(selection: selection)
        case "media":
            MediaDetail(selection: selection)
        default:
            FoundationsDetail(selection: selection)
        }
    }
}

// MARK: - Detail: Foundations

struct FoundationsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "color":
            HStack(spacing: .small) {
                Button("Accent", prominence: .primary)
                    .tint(.accent)
                Button("Danger", prominence: .primary)
                    .tint(.danger)
                Button("Custom", prominence: .primary)
                    .tint(.css("#22a06b"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "textblock":
            VStack(alignment: .leading, spacing: .small) {
                TextBlock("Paragraph copy for long-form content. TextBlock keeps body text semantic while using SwiftWebUI tone tokens.")
                TextBlock("Muted paragraph copy is useful for support text, captions, and explanatory content.", tone: .muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "materials":
            CatalogGlassStage {
                Grid(minColumnWidth: "150px", spacing: .medium) {
                    CatalogMaterialSwatch("Ultra thin", code: ".ultraThinMaterial", material: .ultraThinMaterial)
                    CatalogMaterialSwatch("Thin", code: ".thinMaterial", material: .thinMaterial)
                    CatalogMaterialSwatch("Regular", code: ".regularMaterial", material: .regularMaterial)
                    CatalogMaterialSwatch("Thick", code: ".thickMaterial", material: .thickMaterial)
                    CatalogMaterialSwatch("Ultra thick", code: ".ultraThickMaterial", material: .ultraThickMaterial)
                    CatalogMaterialSwatch("Bar", code: ".bar", material: .bar)
                }
            }
        case "glass":
            CatalogGlassStage {
                GlassEffectContainer(spacing: .medium) {
                    Text("Regular glass")
                        .padding(.all, "12px 18px")
                        .glassEffect(.regular, in: .capsule)
                    Text("Tinted + interactive")
                        .padding(.all, "12px 18px")
                        .glassEffect(.regular.tint("var(--swui-accent)").interactive(), in: .capsule)
                }

                HStack(spacing: .small) {
                    Button("Glass", prominence: .primary)
                        .buttonStyle(.glass)
                    Button("Glass prominent", prominence: .primary)
                        .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            Heading("Page heading", level: .page)
            Heading("Section heading", level: .section)
            Heading("Subsection heading", level: .subsection)
            Text("Body copy uses the base text token and a comfortable line height for long-form reading.")
            Text("Muted secondary copy for captions and hints.", tone: .muted)
            HStack(spacing: .medium) {
                Text("Strong", as: .strong)
                Text("Small print", as: .small, tone: .muted)
                CatalogCodeChip("inline.code()")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Detail: Buttons & actions

struct ButtonsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "button-styles":
            CatalogGlassStage {
                HStack(spacing: .small) {
                    Button("Glass", prominence: .primary)
                        .buttonStyle(.glass)
                    Button("Glass prominent", prominence: .primary)
                        .buttonStyle(.glassProminent)
                    Button("Plain")
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "control-sizes":
            HStack(spacing: .small) {
                Button("Mini", prominence: .primary)
                    .controlSize(.mini)
                Button("Small", prominence: .primary)
                    .controlSize(.small)
                Button("Regular", prominence: .primary)
                    .controlSize(.regular)
                Button("Large", prominence: .primary)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "button-states":
            HStack(spacing: .small) {
                Button("Enabled", prominence: .primary)
                Button("Disabled", prominence: .primary)
                    .disabled()
                SubmitButton("Submit")
                    .disabled()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "links":
            HStack(spacing: .small) {
                ButtonLink("Primary link", href: "#", prominence: .primary)
                ButtonLink("Secondary link", href: "#", prominence: .secondary)
                Link("Anchor", href: "#")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .small) {
                Button("Primary", prominence: .primary)
                Button("Secondary")
                Button("Plain")
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Detail: Inputs & controls

struct InputsDetail: Component {
    let selection: String
    let name: Binding<String>
    let email: Binding<String>
    let secret: Binding<String>
    let notes: Binding<String>
    let enabled: Binding<Bool>
    let volume: Binding<Double>
    let density: Binding<Int>
    let due: Binding<Date>
    let accent: Binding<String>

    var body: some HTML {
        switch selection {
        case "securefield":
            SecureField("Secret", text: secret)
        case "texteditor":
            TextEditor(text: notes)
        case "toggle":
            Toggle("Enabled", isOn: enabled)
        case "slider":
            Slider(value: volume, in: 0...1, step: 0.05)
        case "stepper":
            Stepper("Density", value: density, in: 0...8)
            ValueDisplay(label: "Density", value: density.wrappedValue)
        case "datepicker":
            DatePicker("Due date", selection: due)
            DatePicker(
                "Starts at",
                selection: due,
                displayedComponents: [.date, .hourAndMinute]
            )
        case "colorpicker":
            ColorPicker("Accent", selection: accent)
        case "form":
            Form(action: "/subscribe", method: .post) {
                VStack(alignment: .leading, spacing: .medium) {
                    Label("Email address", systemImage: "envelope")
                    HStack(spacing: .small) {
                        SubmitButton("Subscribe", prominence: .primary)
                            .name("intent")
                            .value("subscribe")
                        SubmitButton("Unsubscribe")
                            .name("intent")
                            .value("unsubscribe")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            TextField("Name", text: name)
            TextField("Email", text: email, .type(.email), .required)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .submitLabel(.go)
        }
    }
}

// MARK: - Detail: Pickers & menus

struct PickersDetail: Component {
    let selection: String
    let pick: Binding<String>
    let segment: Binding<String>
    let scope: Binding<String>
    let menuPick: Binding<String>

    var body: some HTML {
        switch selection {
        case "menu":
            Menu("Options") {
                Button("Duplicate") {}
                Button("Move…") {}
                Button("Delete") {}
            }
        default:
            CatalogVariant("Automatic (dropdown)") {
                Picker("Export format", selection: pick) {
                    PickerOption("JSON", value: "json")
                    PickerOption("CSV", value: "csv")
                    PickerOption("XML", value: "xml")
                }
            }
            CatalogVariant("Segmented") {
                Picker("View", selection: segment) {
                    PickerOption("List", value: "list")
                    PickerOption("Grid", value: "grid")
                    PickerOption("Columns", value: "columns")
                }
                .pickerStyle(.segmented)
            }
            CatalogVariant("Inline") {
                Picker("Scope", selection: scope) {
                    PickerOption("All", value: "all")
                    PickerOption("Unread", value: "unread")
                    PickerOption("Flagged", value: "flagged")
                }
                .pickerStyle(.inline)
            }
            CatalogVariant("Menu") {
                Picker("Sort by", selection: menuPick) {
                    PickerOption("Name", value: "name")
                    PickerOption("Date", value: "date")
                    PickerOption("Size", value: "size")
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - Detail: Containers

struct ContainersDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "badge":
            HStack(spacing: .small) {
                Badge("Default")
                Badge("Ready")
                Badge("Beta")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "toolbar":
            Toolbar {
                Button("Back")
                    .buttonStyle(.plain)
                Spacer()
                Button("Preview")
                Button("Save", prominence: .primary)
            }
        case "valuedisplay":
            HStack(spacing: .medium) {
                ValueDisplay(label: "Score", value: 42)
                ValueDisplay(label: "Streak", value: 7)
                ValueDisplay(label: "Grade", value: "A+")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "list":
            List {
                ListRow {
                    Text("Wi-Fi")
                    Spacer()
                    Badge("On")
                }
                ListRow {
                    Text("Bluetooth")
                    Spacer()
                    Text("Off", tone: .muted)
                }
                ListRow {
                    Text("Updates")
                    Spacer()
                    Badge("3")
                }
            }
        case "section":
            Section("Account", footer: "Signed in as ada@example.com") {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Profile")
                    Text("Security")
                    Text("Notifications")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "disclosuregroup":
            DisclosureGroup("Advanced options", isExpanded: true) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Nested content reveals when expanded.", tone: .muted)
                    Label("Verbose logging", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup("Collapsed by default") {
                Text("Hidden until toggled.", tone: .muted)
            }
        case "grid":
            Grid(minColumnWidth: "120px", spacing: .small) {
                Badge("Cell 1")
                Badge("Cell 2")
                Badge("Cell 3")
                Badge("Cell 4")
            }
        case "lazy":
            Grid(minColumnWidth: "220px", spacing: .large) {
                CatalogVariant("LazyVStack") {
                    LazyVStack(alignment: .leading, spacing: .small) {
                        Badge("Row 1")
                        Badge("Row 2")
                        Badge("Row 3")
                    }
                }
                CatalogVariant("LazyHStack") {
                    LazyHStack(spacing: .small) {
                        Badge("A")
                        Badge("B")
                        Badge("C")
                    }
                }
                CatalogVariant("LazyVGrid") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .small) {
                        Badge("1")
                        Badge("2")
                        Badge("3")
                        Badge("4")
                    }
                }
                CatalogVariant("LazyHGrid") {
                    LazyHGrid(rows: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: .small) {
                        Badge("1")
                        Badge("2")
                        Badge("3")
                        Badge("4")
                    }
                }
            }
        case "scrollview":
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: .small) {
                    Badge("Item 01")
                    Badge("Item 02")
                    Badge("Item 03")
                    Badge("Item 04")
                    Badge("Item 05")
                    Badge("Item 06")
                    Badge("Item 07")
                    Badge("Item 08")
                }
                .padding(.all, "8px")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, height: "160px")
            .background("var(--swui-surface-raised)")
            .cornerRadius("12px")
            .style { .border("1px solid var(--swui-border)") }
        default:
            Card {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Card title", level: .subsection)
                    Text("Cards group related content on the shared surface material.", tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Detail: Status

struct StatusDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "gauge":
            Gauge(value: 0.25, label: "Disk")
            Gauge(value: 0.62, label: "CPU")
            Gauge(value: 0.9, label: "Memory")
        default:
            ProgressView("Uploading", value: 0.35)
            ProgressView("Rendering", value: 0.7)
            ProgressView("Loading")
        }
    }
}

// MARK: - Detail: Navigation & tabs

struct NavigationDetail: Component {
    let selection: String
    let tab: Binding<String>
    let query: Binding<String>

    var body: some HTML {
        switch selection {
        case "tabview":
            TabView(selection: tab) {
                Tab("Summary", systemImage: "doc.text", value: "summary") {
                    Text("Summary panel content.", tone: .muted)
                }
                Tab("Activity", systemImage: "chart.bar", value: "activity") {
                    Text("Activity panel content.", tone: .muted)
                }
                Tab("Settings", systemImage: "gear", value: "settings") {
                    Text("Settings panel content.", tone: .muted)
                }
            }
        case "navigationlink":
            VStack(alignment: .leading, spacing: .small) {
                NavigationLink("Overview", href: "#overview")
                NavigationLink(href: "#settings") {
                    Label("Settings", systemImage: "gear")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "searchable":
            List {
                ListRow { Text("Inbox") }
                ListRow { Text("Drafts") }
                ListRow { Text("Sent") }
            }
            .searchable(text: query)
        default:
            NavigationStack {
                VStack(alignment: .leading, spacing: .small) {
                    NavigationLink("Overview", href: "#")
                    NavigationLink("Components", href: "#components")
                    NavigationLink("Tokens", href: "#tokens")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Detail: Presentation

struct PresentationDetail: Component {
    let selection: String
    let showsAlert: Binding<Bool>
    let showsConfirmation: Binding<Bool>
    let showsSheet: Binding<Bool>
    let showsPopover: Binding<Bool>

    var body: some HTML {
        switch selection {
        case "sheet":
            HStack(spacing: .small) {
                Button("Show sheet") { showsSheet.wrappedValue = true }
                Button("Show popover") { showsPopover.wrappedValue = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: showsSheet) {
                VStack(alignment: .leading, spacing: .medium) {
                    Heading("Sheet", level: .section)
                    Text("A sheet composes the thick material and lifts to the top layer.", tone: .muted)
                    Button("Done") { showsSheet.wrappedValue = false }
                }
            }
            .popover(isPresented: showsPopover) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Popover content anchored to its source.", tone: .muted)
                    Button("Close") { showsPopover.wrappedValue = false }
                }
            }
        default:
            HStack(spacing: .small) {
                Button("Show alert") { showsAlert.wrappedValue = true }
                Button("Show confirmation") { showsConfirmation.wrappedValue = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .alert("Delete this draft?", isPresented: showsAlert) {
                Button("Delete", action: Action.post("/storyboard/delete"))
            } message: {
                Text("This action cannot be undone.")
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: showsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", action: Action.post("/storyboard/discard"))
                Button("Keep editing") { showsConfirmation.wrappedValue = false }
            }
        }
    }
}

// MARK: - Detail: Layout

struct LayoutDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "spacer":
            HStack(spacing: .small) {
                Badge("leading")
                Spacer()
                Badge("trailing")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Text("Above and below are separated by a Divider.", as: .small, tone: .muted)
        case "hug-fill":
            HStack(spacing: .small) {
                Badge("fixedSize()")
                Text("stays at content width", tone: .muted)
            }
            .padding(.all, "12px 16px")
            .background("color-mix(in srgb, var(--swui-accent) 12%, var(--swui-surface-raised))")
            .cornerRadius("12px")
            .style { .border("1px solid color-mix(in srgb, var(--swui-accent) 32%, transparent)") }
            .fixedSize()

            HStack(spacing: .small) {
                Badge("frame(maxWidth: .infinity)")
                Text("stretches to the full column", tone: .muted)
            }
            .padding(.all, "12px 16px")
            .background("color-mix(in srgb, var(--swui-accent) 12%, var(--swui-surface-raised))")
            .cornerRadius("12px")
            .style { .border("1px solid color-mix(in srgb, var(--swui-accent) 32%, transparent)") }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Grid(minColumnWidth: "180px", spacing: .large) {
                CatalogVariant("VStack") {
                    VStack(alignment: .leading, spacing: .small) {
                        Badge("Top")
                        Badge("Middle")
                        Badge("Bottom")
                    }
                }
                CatalogVariant("HStack") {
                    HStack(spacing: .small) {
                        Badge("A")
                        Badge("B")
                        Badge("C")
                    }
                }
                CatalogVariant("ZStack") {
                    ZStack(alignment: .center) {
                        Text(" ")
                            .frame(width: "160px", height: "64px")
                            .background("color-mix(in srgb, var(--swui-accent) 16%, transparent)")
                            .cornerRadius("10px")
                        Badge("Overlay")
                    }
                }
            }
        }
    }
}

// MARK: - Detail: Media

struct MediaDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "label":
            HStack(spacing: .large) {
                Label("Verified", systemImage: "checkmark.seal.fill")
                Label("Favorite", systemImage: "heart.fill")
                Label("Pinned", systemImage: "pin.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .medium) {
                Image(systemName: "star.fill")
                Image(systemName: "bell.badge")
                Image(systemName: "gearshape")
                Image(systemName: "person.crop.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Catalog root

/// The full component catalog as a single client component. It owns the
/// selection plus every piece of demo state, so the sidebar drives the detail
/// and inspector and the top-bar controls retheme the page live by re-applying
/// the environment on each change.
public struct StoryboardCatalog: ClientComponent, Sendable {
    @State private var selection = catalogDefaultSelection
    @State private var theme = Theme.light
    @State private var styleID = "swift-web"
    @State private var name = "Ada Lovelace"
    @State private var email = "ada@example.com"
    @State private var secret = "hunter2"
    @State private var notes = "Notes support multiple lines."
    @State private var enabled = true
    @State private var volume = 0.6
    @State private var density = 3
    @State private var due = Date(timeIntervalSince1970: 1_718_000_000)
    @State private var accent = "#3366ff"
    @State private var pick = "json"
    @State private var segment = "grid"
    @State private var scope = "all"
    @State private var menuPick = "name"
    @State private var tab = "summary"
    @State private var query = ""
    @State private var showsAlert = false
    @State private var showsConfirmation = false
    @State private var showsSheet = false
    @State private var showsPopover = false

    public init(initialSelection: String = catalogDefaultSelection) {
        self._selection = State(wrappedValue: initialSelection)
    }

    public var body: some HTML {
        main(.class("storyboard-page")) {
            VStack(spacing: Space.none) {
                CatalogTopBar(theme: $theme, styleID: $styleID)
                HStack(alignment: .top, spacing: Space.none) {
                    CatalogSidebar(selection: $selection)
                    CatalogDetail(
                        selection: selection,
                        name: $name,
                        email: $email,
                        secret: $secret,
                        notes: $notes,
                        enabled: $enabled,
                        volume: $volume,
                        density: $density,
                        due: $due,
                        accent: $accent,
                        pick: $pick,
                        segment: $segment,
                        scope: $scope,
                        menuPick: $menuPick,
                        tab: $tab,
                        query: $query,
                        showsAlert: $showsAlert,
                        showsConfirmation: $showsConfirmation,
                        showsSheet: $showsSheet,
                        showsPopover: $showsPopover
                    )
                    CatalogInspector(selection: selection)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .style {
                    .custom("flex", "1 1 auto")
                    .custom("min-height", "0")
                    .custom("overflow", "hidden")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .style {
                .height("100%")
            }
        }
        .environment(\.theme, theme)
        .environment(\.styleSystem, catalogStyleSystem(for: styleID))
    }
}
