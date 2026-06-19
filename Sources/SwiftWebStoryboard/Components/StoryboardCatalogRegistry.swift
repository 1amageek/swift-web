import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Style mapping

func catalogStyleSystem(for id: String) -> StyleSystem {
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

    public var path: String {
        catalogPath(for: id)
    }

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

public let catalogBasePath = "/storyboard"
public let catalogDefaultSelection = "typography"

public func catalogPath(for id: String) -> String {
    "\(catalogBasePath)/\(id)"
}

public func catalogSelectionID(for id: String) -> String {
    catalogItem(for: id) == nil ? catalogDefaultSelection : id
}

func catalogItem(for id: String) -> CatalogItem? {
    for category in catalogCategories {
        for item in category.items where item.id == id {
            return item
        }
    }
    return nil
}

func catalogCategory(for itemID: String) -> CatalogCategory? {
    for category in catalogCategories where category.items.contains(where: { $0.id == itemID }) {
        return category
    }
    return nil
}
