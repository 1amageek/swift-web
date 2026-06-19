import Foundation

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

public let catalogCategories: [CatalogCategory] = [
    CatalogCategory(id: "foundations", title: "Foundations", items: [
        CatalogItem(id: "gridsystem", name: "Grid system", code: "GridSystem(columns:gutter:)", summary: "A grid system arranges every element on an 8px lattice of margins, columns, and gutters."),
        CatalogItem(id: "spacing", name: "Spacing & grid", code: "Space.small · Space.medium · Space.large", summary: "Every size and offset is a multiple of an 8px base unit."),
        CatalogItem(id: "alignment", name: "Alignment", code: ".frame(alignment:)", summary: "A view placed on its own is centered in the space it is given, matching SwiftUI."),
        CatalogItem(id: "hug-fill", name: "Flexible & fixed", code: ".fixedSize() · .frame(maxWidth: .infinity)", summary: "Components either keep intrinsic size or grow to fill the parent."),
        CatalogItem(id: "style", name: "Style", code: ".swui-text · .swui-list · .swui-toolbar", summary: "Components emit stable semantic classes and the cascade defines contextual styling."),
        CatalogItem(id: "responsive", name: "Responsive", code: "compact · regular · large", summary: "The same lattice changes column count and gutter by width; content reflows rather than scaling."),
        CatalogItem(id: "safearea", name: "Safe area", code: "ignoresSafeArea()", summary: "SwiftWebUI keeps content away from browser and device chrome by default."),
    ]),
    CatalogCategory(id: "content", title: "Content", items: [
        CatalogItem(id: "typography", name: "Text", code: "Text(_:as:)", summary: "Displays read-only text with semantic font, weight, alignment, and foreground style."),
        CatalogItem(id: "image", name: "Image", code: "Image(systemName:)", summary: "An SF Symbol name renders as a symbol span."),
        CatalogItem(id: "colorvalue", name: "Color", code: "Color.blue.opacity(_:)", summary: "A color paints the region it is given and resolves per appearance."),
    ]),
    CatalogCategory(id: "layout", title: "Layout & organization", items: [
        CatalogItem(id: "code", name: "Code", code: "CodeBlock(_:language:)", summary: "Code renders source as a preformatted block with optional line numbers."),
        CatalogItem(id: "label", name: "Label", code: "Label(_:systemImage:)", summary: "Pairs an icon with a title."),
        CatalogItem(id: "groupbox", name: "GroupBox", code: "GroupBox { }", summary: "A titled container that groups related views on one bordered surface."),
        CatalogItem(id: "list", name: "List", code: "List { ListRow { } }", summary: "A container of rows with styles such as plain, inset, grouped, and sidebar."),
        CatalogItem(id: "section", name: "Section", code: "Section(_:footer:)", summary: "Groups rows inside a List or Form under an optional header and footer."),
        CatalogItem(id: "disclosuregroup", name: "DisclosureGroup", code: "DisclosureGroup(_:isExpanded:)", summary: "An expandable region that composes the regular material."),
        CatalogItem(id: "grid", name: "Grid", code: "Grid(minColumnWidth:spacing:)", summary: "A responsive grid that wraps at a minimum column width."),
        CatalogItem(id: "lazy", name: "Lazy stacks", code: "LazyVStack · LazyHStack", summary: "LazyVStack and LazyHStack build only the children that scroll into view."),
        CatalogItem(id: "tabview", name: "TabView", code: "TabView(selection:) { Tab }", summary: "Switches panels; the tab bar composes interactive glass."),
        CatalogItem(id: "stacks", name: "Stacks", code: "VStack · HStack · ZStack", summary: "VStack and HStack arrange along an axis; ZStack overlays."),
        CatalogItem(id: "spacer", name: "Spacer", code: "Spacer()", summary: "A flexible space that expands along the enclosing stack axis."),
        CatalogItem(id: "divider", name: "Divider", code: "Divider()", summary: "A hairline rule that separates content horizontally or vertically."),
    ]),
    CatalogCategory(id: "menus", title: "Menus & actions", items: [
        CatalogItem(id: "button", name: "Button", code: "Button(_:prominence:)", summary: "A button runs an action when pressed. Prominence sets its visual weight."),
        CatalogItem(id: "button-styles", name: "Button styles", code: ".buttonStyle(.glass)", summary: "buttonStyle(_:) switches the button recipe independently of its action."),
        CatalogItem(id: "control-sizes", name: "Control sizes", code: ".controlSize(.large)", summary: "controlSize(_:) scales a control's padding and type together."),
        CatalogItem(id: "button-states", name: "Tint & disabled", code: ".tint(.accent) · .disabled()", summary: "tint(_:) recolors an enabled control; disabled() dims it and blocks interaction."),
        CatalogItem(id: "links", name: "Links", code: "Link(_:href:)", summary: "Link is a semantic anchor for navigation and can be restyled as a button."),
        CatalogItem(id: "menu", name: "Menu", code: "Menu(_:content:)", summary: "A pull-down list of actions disclosed on demand."),
        CatalogItem(id: "toolbar", name: "Toolbar", code: "Toolbar { }", summary: "A horizontal command surface that composes the bar material and fills its container."),
    ]),
    CatalogCategory(id: "navigation", title: "Navigation & search", items: [
        CatalogItem(id: "navigationstack", name: "NavigationStack", code: "NavigationStack { NavigationLink }", summary: "A single-column navigation container that renders a semantic nav."),
        CatalogItem(id: "navigationlink", name: "NavigationLink", code: "NavigationLink(_:href:)", summary: "A semantic navigation row or inline control that points to another location."),
        CatalogItem(id: "searchable", name: "Searchable", code: ".searchable(text:prompt:)", summary: "Adds a search field bound to a query over a collection."),
    ]),
    CatalogCategory(id: "presentation", title: "Presentation", items: [
        CatalogItem(id: "alert", name: "Alert & dialog", code: ".alert(_:isPresented:)", summary: "Alert and confirmationDialog interrupt for a decision."),
        CatalogItem(id: "sheet", name: "Sheet & popover", code: ".sheet(isPresented:)", summary: "sheet(isPresented:) lifts a panel; popover(isPresented:) anchors to its source."),
        CatalogItem(id: "scrollview", name: "ScrollView", code: "ScrollView(.vertical)", summary: "Clips overflow on its axis and scrolls within a fixed frame."),
    ]),
    CatalogCategory(id: "input", title: "Selection & input", items: [
        CatalogItem(id: "textfield", name: "TextField", code: "TextField(_:text:)", summary: "Text entry bound to a String with input type, validation, and content hints."),
        CatalogItem(id: "securefield", name: "SecureField", code: "SecureField(_:text:)", summary: "Masked entry for secrets with autofill content-type semantics."),
        CatalogItem(id: "texteditor", name: "TextEditor", code: "TextEditor(text:)", summary: "Multi-line text entry that composes the thin material."),
        CatalogItem(id: "form", name: "Form", code: "Form(action:method:)", summary: "A Form posts to an action; SubmitButtons carry name and value."),
        CatalogItem(id: "toggle", name: "Toggle", code: "Toggle(_:isOn:)", summary: "A boolean switch; the track composes the unified material."),
        CatalogItem(id: "slider", name: "Slider", code: "Slider(value:in:step:)", summary: "A continuous value across a range with an optional step."),
        CatalogItem(id: "stepper", name: "Stepper", code: "Stepper(_:value:in:)", summary: "Increment or decrement a discrete value within bounds."),
        CatalogItem(id: "picker", name: "Picker", code: ".pickerStyle(.segmented)", summary: "pickerStyle(_:) chooses dropdown, segmented, inline, or menu without changing the binding."),
        CatalogItem(id: "datepicker", name: "DatePicker", code: "DatePicker(_:selection:)", summary: "datePickerStyle picks the presentation while the binding owns the selected date."),
        CatalogItem(id: "colorpicker", name: "ColorPicker", code: "ColorPicker(_:selection:)", summary: "A native color well bound to a hex string."),
        CatalogItem(id: "color", name: "Color & tint", code: ".tint(.accent)", summary: "tint(_:) applies a semantic or custom color to a control without changing the global theme."),
    ]),
    CatalogCategory(id: "status", title: "Status", items: [
        CatalogItem(id: "progressview", name: "ProgressView", code: "ProgressView(_:value:)", summary: "A determinate bar with a value, or an indeterminate spinner without one."),
        CatalogItem(id: "gauge", name: "Gauge", code: "Gauge(value:label:)", summary: "A compact readout of a value within a range."),
        CatalogItem(id: "badge", name: "Badge", code: "Badge(_:)", summary: "A compact status pill that hugs its label."),
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
