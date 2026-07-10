import Foundation
import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
#if canImport(SwiftWebUIRuntime)
import SwiftWebUIRuntime
#endif

/// The live, stateful part of a Storyboard detail page.
///
/// The catalog chrome, documentation metadata, and related links stay
/// server-rendered. This keeps the client hydration surface proportional to the
/// interactive example instead of the whole Storyboard shell.
public struct StoryboardDetailIsland: ClientComponent, Sendable {
    private let selection: String
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
    @State private var advancedOptionsExpanded = true
    @State private var animateOn = false
    @State private var ui: [String: String] = [:]

    public init(initialSelection: String = catalogDefaultSelection) {
        self.selection = catalogSelectionID(for: initialSelection)
    }

    public var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            previewSection()
            codeSection(
                anchor: "usage",
                title: "Usage",
                text: catalogSnippet(for: selection, state: ui),
                language: "swift",
                showsLineNumbers: true
            )
            domContractSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func selection(from href: String) -> String {
        guard let url = URL(string: href) else {
            return catalogDefaultSelection
        }
        let pathComponents = url.path.split(separator: "/").map(String.init)
        guard let storyboardIndex = pathComponents.firstIndex(of: "storyboard") else {
            return catalogDefaultSelection
        }
        let selectionIndex = pathComponents.index(after: storyboardIndex)
        guard pathComponents.indices.contains(selectionIndex) else {
            return catalogDefaultSelection
        }
        return pathComponents[selectionIndex]
    }

    private func sectionTitle(_ title: String, anchor: String) -> some HTML {
        Text(title, .id(anchor)).as(.h2)
            .font(.headline)
            .fontWeight(.semibold)
    }

    @HTMLBuilder
    private func previewSection() -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Playground", anchor: "preview")
            Text("Drive the live component; the usage snippet follows every knob.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            PreviewFrame {
                PreviewCanvas(scene: StoryboardScene.scene(forItem: selection)) {
                    detailDemo()
                }
                StoryboardControlPanel(id: selection, ui: $ui)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func codeSection(
        anchor: String,
        title: String,
        text: String,
        language: String,
        showsLineNumbers: Bool
    ) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle(title, anchor: anchor)
            Code(language: language, showsLineNumbers: showsLineNumbers) { text }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func domContractSection() -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            div(.class("swui-storyboard-section-rule")) { EmptyHTML() }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Stable semantic and utility classes emitted by the preview. Internal generated atom classes and runtime attributes are omitted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Code(language: "html", showsLineNumbers: false) { domContractHTML() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("DOM Contract", .id("dom-contract")).as(.span)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func domContractHTML() -> String {
        let html: String
        if StyleRegistry.current != nil {
            html = detailDemo().render()
        } else {
            let registry = StyleRegistry()
            html = StyleRegistry.withCurrent(registry) {
                detailDemo().render()
            }
        }
        return storyboardPrettyPrintedHTML(storyboardDOMContractHTML(from: html))
    }

    private func codeSample(_ language: String) -> String {
        switch language {
        case "json":
            return "{\n  \"columns\": 12,\n  \"gutter\": \"medium\"\n}"
        case "bash":
            return "swift run sweb storyboard"
        default:
            return "struct Counter: View {\n    @State private var count = 0\n}"
        }
    }

    @HTMLBuilder
    private func detailDemo() -> some HTML {
        switch selection {
        case "gridsystem", "spacing", "alignment", "style", "responsive", "safearea", "materials":
            FoundationsDetail(selection: selection, state: ui)
        case "typography", "colorvalue":
            FoundationsDetail(selection: selection, state: ui)
        case "image", "asyncimage", "label":
            MediaDetail(selection: selection, state: ui)
        case "code":
            let language = ui.control("code", "lang")
            Code(
                language: language,
                startLine: Int(ui.controlNumber("code", "startLine")),
                showsLineNumbers: ui.controlFlag("code", "lineNumbers")
            ) {
                codeSample(language)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "groupbox", "list", "section", "disclosuregroup", "grid", "lazy", "scrollview", "toolbar", "badge":
            ContainersDetail(selection: selection, ui: $ui)
        case "tabview", "navigationstack", "navigationlink", "searchable":
            NavigationDetail(selection: selection, ui: $ui)
        case "stacks", "spacer", "divider", "hug-fill":
            LayoutDetail(selection: selection, state: ui)
        case "button", "button-styles", "control-sizes", "button-states", "links":
            ButtonsDetail(selection: selection, state: ui)
        case "animation", "transition", "withanimation":
            AnimationDetail(selection: selection, ui: $ui)
        case "menu", "picker":
            PickersDetail(selection: selection, ui: $ui)
        case "securefield", "texteditor", "toggle", "slider", "stepper", "datepicker", "calendar", "colorpicker", "form", "textfield":
            InputsDetail(selection: selection, ui: $ui, due: $due)
        case "color":
            FoundationsDetail(selection: selection, state: ui)
        case "progressview", "gauge":
            StatusDetail(selection: selection, state: ui)
        case "alert", "sheet":
            PresentationDetail(selection: selection, ui: $ui)
        default:
            FoundationsDetail(selection: selection, state: ui)
        }
    }
}

#if canImport(SwiftWebUIRuntime)
extension StoryboardDetailIsland: ClientRuntimeBootstrapInitializable {
    public init(bootstrap request: ClientRuntimeBootstrapRequest) throws {
        self.init(initialSelection: Self.selection(from: request.location.href))
    }
}
#endif
