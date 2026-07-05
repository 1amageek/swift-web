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
    /// Longer discussion paragraphs: what the component is for, when to reach
    /// for it, and how it behaves on the web. Empty falls back to `overview`.
    let discussion: [String]
    /// The SwiftUI-parity note — the framework's core promise, stated per page.
    let swiftUIParity: String?
    /// Curated static configurations shown before the playground.
    let variants: [CatalogVariant]
    let properties: [CatalogProperty]
    let snippet: String
}

func catalogDetailSpec(for item: CatalogItem) -> CatalogDetailSpec {
    CatalogDetailSpec(
        overview: catalogOverview(for: item),
        discussion: catalogDiscussion(for: item.id),
        swiftUIParity: catalogSwiftUIParity(for: item.id),
        variants: catalogVariants(for: item.id),
        properties: catalogProperties(for: item.id),
        snippet: catalogSnippet(for: item.id)
    )
}

private func catalogOverview(for item: CatalogItem) -> String {
    item.summary
}

private func catalogProperties(for id: String) -> [CatalogProperty] {
    switch id {
    case "gridsystem":
        return [
            CatalogProperty("GridSystem(columns:gutter:)", values: "container", summary: "Configures the column count and gutter from the 8px scale."),
            CatalogProperty("columns", values: "4 / 8 / 12", summary: "Divides the content canvas into whole-number tracks."),
            CatalogProperty("Pane(span:)", values: "1...columns", summary: "Declares how many columns a child occupies."),
        ]
    case "spacing":
        return [
            CatalogProperty("base unit", values: "8px", summary: "The atomic spacing step."),
            CatalogProperty(".small / .medium / .large", values: "8 / 12 / 16px", summary: "Named spacing tokens resolved by the active theme."),
            CatalogProperty("half-step", values: "4px", summary: "Reserved for fine optical alignment."),
        ]
    case "alignment":
        return [
            CatalogProperty("default", values: ".center", summary: "A lone view is centered in its container by default."),
            CatalogProperty("frame(alignment:)", values: ".leading / .center / .trailing", summary: "Positions content within the view's available space."),
            CatalogProperty("multilineTextAlignment", values: ".leading / .center / .trailing", summary: "Aligns wrapped text lines inside their own box."),
        ]
    case "style":
        return [
            CatalogProperty("class-only DOM", values: "no inline styles", summary: "Components emit stable semantic class hooks."),
            CatalogProperty("semantic class", values: "swui-text / swui-list / swui-toolbar", summary: "Every component exposes a cascade hook."),
            CatalogProperty("token utility", values: "swui-bg-surface / swui-fg-secondary", summary: "Theme tokens are emitted once in the base stylesheet."),
            CatalogProperty("variant utility", values: "hover:swui-bg-accent / md:swui-fg-secondary", summary: "SwiftWebStyle compiles conditional classes into typed selectors and at-rules."),
        ]
    case "responsive":
        return [
            CatalogProperty("compact", values: "< 600px", summary: "Single stacked column with reduced margins."),
            CatalogProperty("regular", values: "600-1024px", summary: "Eight-column grid with medium gutters."),
            CatalogProperty("large", values: "> 1024px", summary: "Twelve-column grid with wider margins."),
        ]
    case "safearea":
        return [
            CatalogProperty("viewport-fit=cover", values: "default meta", summary: "Lets env(safe-area-inset-*) return real values."),
            CatalogProperty("root scene inset", values: "env(...)", summary: "Pads content away from device and browser chrome."),
            CatalogProperty("ignoresSafeArea()", values: "opt-out", summary: "Lets one element extend to the edge."),
        ]
    case "typography":
        return [
            CatalogProperty("Text(_:)", values: "String", summary: "The read-only string the view renders."),
            CatalogProperty("as(_:)", values: ".h1–.h6 / .span / .code / .label / …", summary: "Renders the text as a different HTML element."),
            CatalogProperty("font", values: ".largeTitle / .title / .headline / .body / .caption", summary: "Applies a semantic font preset."),
            CatalogProperty("foregroundStyle", values: ".primary / .secondary / .accent / .danger", summary: "Sets color from a semantic role."),
        ]
    case "code":
        return [
            CatalogProperty("content", values: "@StringBuilder closure", summary: "The source code, supplied as a trailing closure."),
            CatalogProperty("language", values: "String", summary: "Language hint emitted as data-language and the aria label."),
            CatalogProperty("startLine", values: "Int", summary: "The number assigned to the first line."),
            CatalogProperty("showsLineNumbers", values: "Bool", summary: "Toggles the leading line-number gutter."),
        ]
    case "colorvalue":
        return [
            CatalogProperty("Color.<name>", values: "static color", summary: "A standard system color with light and dark values."),
            CatalogProperty("opacity(_:)", values: "Double", summary: "Returns the color at a fractional alpha."),
            CatalogProperty("frame(width:height:)", values: "modifier", summary: "Defines the region the color paints."),
        ]
    case "color":
        return [
            CatalogProperty("tint", values: ".accent / .danger / Color(hex:)", summary: "Sets the component accent without changing the global color scheme."),
            CatalogProperty("foregroundStyle", values: "semantic or CSS color", summary: "Overrides foreground color for a scoped component."),
            CatalogProperty("background", values: "semantic token or CSS color", summary: "Applies a local fill when a component needs a custom surface."),
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
            CatalogProperty("theme", values: "environment value", summary: "Resolves glass styles differently per theme."),
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
            CatalogProperty("buttonStyle", values: ".glass / .glassProminent / .plain", summary: "Optionally restyles the link to read as a button."),
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
    case "groupbox":
        return [
            CatalogProperty("label", values: "String or @HTMLBuilder", summary: "Optional title shown above grouped content."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Views grouped onto one bordered surface."),
            CatalogProperty("padding", values: "Space or CSS length", summary: "Controls interior spacing."),
        ]
    case "toolbar":
        return [
            CatalogProperty("ToolbarItem(placement:)", values: ".automatic / .navigation / .principal / .primaryAction / .bottomBar", summary: "Routes each item into the leading, principal, trailing, or bottom bar region."),
            CatalogProperty("ToolbarItemGroup(placement:)", values: "shared placement", summary: "Groups several views under one placement."),
            CatalogProperty("material", values: ".bar", summary: "The bar uses the bar material recipe from the active Theme and fills horizontally."),
        ]
    case "badge":
        return [
            CatalogProperty(".badge(_:)", values: "String? / Int", summary: "Attaches a trailing status pill; nil, an empty string, or 0 shows no badge."),
            CatalogProperty("tint", values: "semantic or CSS color", summary: "Communicates category or severity."),
            CatalogProperty("placement", values: "trailing", summary: "The pill sits at the trailing edge of the labeled view or list row."),
        ]
    case "list":
        return [
            CatalogProperty("rows", values: "direct children", summary: "Every direct child of the builder is one row; .badge(_:) attaches trailing content."),
            CatalogProperty("List(_:rowContent:)", values: "Identifiable data or id:", summary: "Derives one semantic row per element, emitting role=\"list\" and role=\"listitem\"."),
            CatalogProperty("spacing", values: "Theme token", summary: "Resolved by the active theme."),
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
            CatalogProperty("isExpanded", values: "Binding<Bool>", summary: "Controls open state."),
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Revealed content."),
        ]
    case "grid":
        return [
            CatalogProperty("alignment", values: "Alignment", summary: "Default alignment for cells."),
            CatalogProperty("horizontalSpacing", values: "Double?", summary: "Horizontal gap between cells in points."),
            CatalogProperty("verticalSpacing", values: "Double?", summary: "Vertical gap between rows in points."),
            CatalogProperty("content", values: "GridRow", summary: "Rows that contain grid cells."),
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
    case "animation":
        return [
            CatalogProperty(".animation(_:value:)", values: "Animation? · Equatable", summary: "Animates subtree changes when value changes."),
            CatalogProperty("Animation", values: ".easeInOut / .spring(duration:bounce:) / .linear …", summary: "A timing curve lowered to a CSS transition."),
            CatalogProperty("delay / speed", values: "modifier", summary: "Shift the start or scale the duration of an animation."),
            CatalogProperty("engine", values: "browser", summary: "Interpolation runs in the browser; there is no Swift-side animation engine."),
        ]
    case "transition":
        return [
            CatalogProperty(".transition(_:)", values: "AnyTransition", summary: "Insertion and removal animation while conditionally present."),
            CatalogProperty("presets", values: ".opacity / .scale / .move(edge:) / .slide", summary: "Built-in insertion and removal effects."),
            CatalogProperty("composition", values: ".asymmetric(insertion:removal:) / .combined(with:)", summary: "Differ per direction or layer two transitions."),
            CatalogProperty("mechanism", values: "@starting-style + delayed remove", summary: "Insertion is pure CSS; removal animates before the runtime detaches the node."),
        ]
    case "withanimation":
        return [
            CatalogProperty("withAnimation(_:_:)", values: "Animation? · () -> Result", summary: "Animates the state changes the closure makes."),
            CatalogProperty("granularity", values: "per event", summary: "Applies to the whole resulting update; the last call in an event wins."),
            CatalogProperty("nil", values: "Animation?", summary: "Runs the body without animating."),
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
    case "divider":
        return [
            CatalogProperty("orientation", values: "inferred from stack", summary: "Horizontal in a VStack and vertical in an HStack."),
            CatalogProperty("style", values: "Theme rule", summary: "The active theme owns the hairline color."),
            CatalogProperty("frame", values: "length modifiers", summary: "Constrains the rule length or thickness."),
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
    case "asyncimage":
        return [
            CatalogProperty("url", values: "URL?", summary: "The image source; nil renders only the placeholder."),
            CatalogProperty("scale", values: "1, 2, 3", summary: "Lowers to a srcset density descriptor (url 2x)."),
            CatalogProperty("content", values: "(Image) -> some HTML", summary: "Styles the underlying image element."),
            CatalogProperty("placeholder", values: "@HTMLBuilder", summary: "Sits beneath the image and shows until it paints — and if it never does."),
        ]
    case "label":
        return [
            CatalogProperty("title", values: "String", summary: "Visible text."),
            CatalogProperty("systemImage", values: "SF Symbol name", summary: "Leading icon."),
            CatalogProperty("spacing", values: "Theme token", summary: "Resolved icon/text gap."),
        ]
    default:
        return [
            CatalogProperty("content", values: "@HTMLBuilder", summary: "Child content rendered inside the component."),
            CatalogProperty("modifiers", values: "SwiftWebUI modifiers", summary: "Frame, padding, tint, style, and environment can be layered as needed."),
        ]
    }
}
