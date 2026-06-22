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

    var body: some HTML {
        main(.class("storyboard-detail")) {
            div(.class("storyboard-detail-content")) {
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
        }
    }

    private var showsRenderedHTML: Bool {
        catalogShowsRenderedHTML(for: selection)
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        if let category = catalogCategory(for: item.id) {
            nav(.class("storyboard-breadcrumb"), .aria("label", "Breadcrumb")) {
                span {
                    category.title
                }
                span(.class("storyboard-breadcrumb-separator"), .aria("hidden", "true")) {
                    "/"
                }
                span(.class("storyboard-breadcrumb-current"), .aria("current", "page")) {
                    item.name
                }
            }
        }
        h1(.class("storyboard-title")) {
            item.name
        }
        p(.class("storyboard-description")) {
            spec.overview
        }
    }

    @HTMLBuilder
    private func previewSection() -> some HTML {
        h2(.class("storyboard-section-title"), .id("preview")) {
            "Preview"
        }
        div(.class("storyboard-preview-frame")) {
            div(.class("storyboard-preview-canvas")) {
                div(.class("swui-root storyboard-preview-root")) {
                    detailDemo()
                }
            }
            previewControls()
        }
    }

    @HTMLBuilder
    private func previewControls() -> some HTML {
        switch selection {
        case "slider":
            div(.class("storyboard-controls")) {
                CatalogRangeControl(label: "Value", value: volume)
            }
        case "stepper":
            div(.class("storyboard-controls")) {
                CatalogStepperControl(label: "Value", value: density)
            }
        case "toggle":
            div(.class("storyboard-controls")) {
                CatalogToggleControl(label: "State", value: enabled)
            }
        case "picker":
            div(.class("storyboard-controls")) {
                CatalogSegmentControl(
                    label: "Selection",
                    selection: segment,
                    options: [
                        CatalogSegmentOption(label: "List", value: "list"),
                        CatalogSegmentOption(label: "Grid", value: "grid"),
                        CatalogSegmentOption(label: "Columns", value: "columns"),
                    ]
                )
            }
        case "textfield":
            div(.class("storyboard-controls")) {
                CatalogTextControl(label: "Email", value: email, placeholder: "ada@example.com")
            }
        case "texteditor":
            div(.class("storyboard-controls")) {
                CatalogTextControl(label: "Notes", value: notes, placeholder: "Notes")
            }
        default:
            EmptyHTML()
        }
    }

    @HTMLBuilder
    private func codeSection(anchor: String, title: String, text: String, language: String, showsLineNumbers: Bool) -> some HTML {
        section(.class("storyboard-section"), .id(anchor)) {
            h2(.class("storyboard-section-title")) {
                title
            }
            CodeBlock(
                text,
                language: language,
                showsLineNumbers: showsLineNumbers,
                .class("storyboard-code-block")
            )
        }
    }

    @HTMLBuilder
    private func renderedHTMLSection() -> some HTML {
        section(.class("storyboard-section"), .id("rendered-html")) {
            h2(.class("storyboard-section-title tight")) {
                "Rendered HTML"
            }
            p(.class("storyboard-section-caption")) {
                "The DOM SwiftWebUI emits for the preview above."
            }
            CodeBlock(
                catalogRenderedHTML(for: selection),
                language: "html",
                showsLineNumbers: false,
                .class("storyboard-code-block rendered")
            )
        }
    }

    @HTMLBuilder
    private func propertiesSection(_ properties: [CatalogProperty]) -> some HTML {
        section(.class("storyboard-section"), .id("properties")) {
            h2(.class("storyboard-section-title tight")) {
                "Properties"
            }
            p(.class("storyboard-section-caption")) {
                "The parameters and modifiers that configure this component."
            }
            CatalogPropertyPanel(properties: properties)
        }
    }

    @HTMLBuilder
    private func relatedSection(item: CatalogItem) -> some HTML {
        section(.class("storyboard-section bottom"), .id("related")) {
            h2(.class("storyboard-section-title related")) {
                "Related"
            }
            CatalogRelatedPanel(selection: item.id)
        }
    }

    @HTMLBuilder
    private func detailDemo() -> some HTML {
        switch selection {
        case "gridsystem", "spacing", "alignment", "style", "responsive", "safearea":
            FoundationsDetail(selection: selection)
        case "typography", "colorvalue":
            FoundationsDetail(selection: selection)
        case "image", "label":
            MediaDetail(selection: selection)
        case "code":
            CodeBlock(catalogSnippet(for: "code"), language: "swift")
                .frame(maxWidth: .infinity, alignment: .leading)
        case "groupbox", "list", "section", "disclosuregroup", "grid", "lazy", "scrollview", "toolbar", "badge":
            ContainersDetail(selection: selection, advancedOptionsExpanded: advancedOptionsExpanded)
        case "tabview", "navigationstack", "navigationlink", "searchable":
            NavigationDetail(selection: selection, tab: tab, query: query)
        case "stacks", "spacer", "divider", "hug-fill":
            LayoutDetail(selection: selection)
        case "button", "button-styles", "control-sizes", "button-states", "links":
            ButtonsDetail(selection: selection)
        case "menu", "picker":
            PickersDetail(selection: selection, pick: pick, segment: segment, scope: scope, menuPick: menuPick)
        case "securefield", "texteditor", "toggle", "slider", "stepper", "datepicker", "colorpicker", "form", "textfield":
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
        case "color":
            FoundationsDetail(selection: selection)
        case "progressview", "gauge":
            StatusDetail(selection: selection)
        case "alert", "sheet":
            PresentationDetail(
                selection: selection,
                showsAlert: showsAlert,
                showsConfirmation: showsConfirmation,
                showsSheet: showsSheet,
                showsPopover: showsPopover
            )
        default:
            FoundationsDetail(selection: selection)
        }
    }
}
