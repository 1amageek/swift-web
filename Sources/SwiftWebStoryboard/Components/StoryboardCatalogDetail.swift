import Foundation
import SwiftHTML
import SwiftWebUI

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
    let advancedOptionsExpanded: Binding<Bool>
    let animateOn: Binding<Bool>
    // The unified control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    var body: some HTML {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: .large) {
                if let item = catalogItem(for: selection) {
                    let spec = catalogDetailSpec(for: item)
                    detailHeader(item: item, spec: spec)
                    previewSection()
                    codeSection(anchor: "usage", title: "Usage", text: spec.snippet, language: "swift", showsLineNumbers: true)
                    if showsRenderedHTML {
                        renderedHTMLSection()
                    }
                    propertiesSection(spec.properties)
                    relatedSection(item: item)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityRole("main")
    }

    private var showsRenderedHTML: Bool {
        // The DOM is generated from the demo, so it is accurate for every
        // component and always shown.
        true
    }

    private func sectionTitle(_ title: String, anchor: String) -> some HTML {
        Text(title, as: .h2, .id(anchor))
            .font(.headline)
            .fontWeight(.semibold)
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        if let category = catalogCategory(for: item.id) {
            HStack(spacing: .xsmall) {
                Text(category.title)
                Text("/").accessibilityHidden(true)
                Text(item.name)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text(item.name, as: .h1)
            .font(.title)
            .fontWeight(.bold)
        Text(spec.overview)
            .foregroundStyle(.secondary)
    }

    @HTMLBuilder
    private func previewSection() -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Preview", anchor: "preview")
            // PreviewFrame is a full-width block, so the canvas always spans the
            // content column regardless of the demo's intrinsic size.
            PreviewFrame {
                // The dot-grid canvas centers the live demo, matching the design.
                PreviewCanvas {
                    detailDemo()
                }
                // The control panel sits below the canvas, separated by a rule.
                StoryboardControlPanel(id: selection, ui: ui)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasPreviewControls: Bool {
        ["slider", "stepper", "toggle", "animation", "transition", "picker", "textfield", "texteditor"].contains(selection)
    }

    @HTMLBuilder
    private func previewControlArea() -> some HTML {
        if hasPreviewControls {
            Divider()
            VStack(alignment: .leading, spacing: .small) {
                previewControls()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.medium)
        }
    }

    @HTMLBuilder
    private func previewControls() -> some HTML {
        switch selection {
        case "slider":
            CatalogRangeControl(label: "Value", value: volume)
        case "stepper":
            CatalogStepperControl(label: "Value", value: density)
        case "toggle":
            CatalogToggleControl(label: "State", value: enabled)
        case "animation", "transition":
            CatalogToggleControl(label: "Animate", value: animateOn)
        case "picker":
            CatalogSegmentControl(
                label: "Selection",
                selection: segment,
                options: [
                    CatalogSegmentOption(label: "List", value: "list"),
                    CatalogSegmentOption(label: "Grid", value: "grid"),
                    CatalogSegmentOption(label: "Columns", value: "columns"),
                ]
            )
        case "textfield":
            CatalogTextControl(label: "Email", value: email, placeholder: "ada@example.com")
        case "texteditor":
            CatalogTextControl(label: "Notes", value: notes, placeholder: "Notes")
        default:
            EmptyHTML()
        }
    }

    @HTMLBuilder
    private func codeSection(anchor: String, title: String, text: String, language: String, showsLineNumbers: Bool) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle(title, anchor: anchor)
            Code(text, language: language, showsLineNumbers: showsLineNumbers)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func renderedHTMLSection() -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Rendered HTML", anchor: "rendered-html")
            Text("The DOM SwiftWebUI emits for the preview above.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Code(renderedDemoHTML(), language: "html", showsLineNumbers: false)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The DOM the live demo emits, generated from the demo itself so it can
    /// never drift out of date (no hand-written copy). Runtime-only hydration
    /// attributes are stripped for readability.
    private func renderedDemoHTML() -> String {
        var html = detailDemo().render()
        html = html.replacingOccurrences(of: #"\s*data-node="[^"]*""#, with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\s*data-event-[a-z]+="[^"]*""#, with: "", options: .regularExpression)
        return html
    }

    @HTMLBuilder
    private func propertiesSection(_ properties: [CatalogProperty]) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Properties", anchor: "properties")
            Text("The parameters and modifiers that configure this component.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            CatalogPropertyPanel(properties: properties)
        }
    }

    @HTMLBuilder
    private func relatedSection(item: CatalogItem) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Related", anchor: "related")
            CatalogRelatedPanel(selection: item.id)
        }
    }

    private func codeSample(_ language: String) -> String {
        switch language {
        case "json":
            return "{\n  \"columns\": 12,\n  \"gutter\": \"medium\"\n}"
        case "bash":
            return "swift run sweb storyboard --port 3001"
        default:
            return "GridSystem(columns: 12, gutter: .medium) {\n    Pane(span: 8) { Article() }\n    Pane(span: 4) { Sidebar() }\n}"
        }
    }

    @HTMLBuilder
    private func detailDemo() -> some HTML {
        switch selection {
        case "gridsystem", "spacing", "alignment", "style", "responsive", "safearea", "materials":
            FoundationsDetail(selection: selection, state: ui.wrappedValue)
        case "typography", "colorvalue":
            FoundationsDetail(selection: selection, state: ui.wrappedValue)
        case "image", "label":
            MediaDetail(selection: selection, state: ui.wrappedValue)
        case "code":
            let language = ui.wrappedValue.control("code", "lang")
            Code(
                codeSample(language),
                language: language,
                showsLineNumbers: ui.wrappedValue.controlFlag("code", "lineNumbers")
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        case "groupbox", "list", "section", "disclosuregroup", "grid", "lazy", "scrollview", "toolbar", "badge":
            ContainersDetail(selection: selection, ui: ui)
        case "tabview", "navigationstack", "navigationlink", "searchable":
            NavigationDetail(selection: selection, ui: ui)
        case "stacks", "spacer", "divider", "hug-fill":
            LayoutDetail(selection: selection, state: ui.wrappedValue)
        case "button", "button-styles", "control-sizes", "button-states", "links":
            ButtonsDetail(selection: selection, state: ui.wrappedValue)
        case "animation", "transition", "withanimation":
            AnimationDetail(selection: selection, ui: ui)
        case "menu", "picker":
            PickersDetail(selection: selection, ui: ui)
        case "securefield", "texteditor", "toggle", "slider", "stepper", "datepicker", "colorpicker", "form", "textfield":
            InputsDetail(selection: selection, ui: ui, due: due)
        case "color":
            FoundationsDetail(selection: selection, state: ui.wrappedValue)
        case "progressview", "gauge":
            StatusDetail(selection: selection, state: ui.wrappedValue)
        case "alert", "sheet":
            PresentationDetail(selection: selection, ui: ui)
        default:
            FoundationsDetail(selection: selection, state: ui.wrappedValue)
        }
    }
}
