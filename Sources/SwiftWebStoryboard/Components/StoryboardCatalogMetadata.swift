import Foundation
import SwiftHTML
import SwiftWebUI

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
