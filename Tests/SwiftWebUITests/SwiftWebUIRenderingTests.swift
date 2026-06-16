import SwiftHTML
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUIRenderingTests {
    @Test
    func rendersThemeAndLayoutPrimitives() {
        let rendered = main(.class("swui-page")) {
            VStack(spacing: .large) {
                VStack(spacing: .small) {
                    Badge("SwiftWeb")
                    Heading("Counter", level: .page)
                    Text("Client and server counters.", tone: .muted)
                }
                Grid {
                    Card {
                        Heading("Client Counter")
                        Text("Runs in WASM.", tone: .muted)
                        ValueDisplay(label: "Client value", value: 0)
                    }
                    .class("client-counter")
                }
            }
        }
        .environment(\.theme, .system)
        .render()

        #expect(rendered.contains("[data-swift-web-ui-theme=\"system\"]"))
        #expect(rendered.contains("[data-swift-web-ui-design-style=\"swift-web\"]"))
        #expect(rendered.contains("--swui-background: #f7f8fa;"))
        #expect(rendered.contains("--swui-button-radius: var(--swui-radius-medium);"))
        #expect(rendered.contains("class=\"swui-root\""))
        #expect(rendered.contains("data-swift-web-ui-theme=\"system\""))
        #expect(rendered.contains("data-swift-web-ui-design-style=\"swift-web\""))
        #expect(rendered.contains("class=\"swui-page\""))
        #expect(rendered.contains("class=\"swui-card client-counter\""))
        #expect(rendered.contains("<output class=\"swui-value\" aria-live=\"polite\">0</output>"))
    }

    @Test
    func rendersDeclarativeDesignStyleBuilderOverrides() {
        let style = DesignStyle(id: "brand") {
            .root {
                .pageInlinePadding("40px")
                .stackSpacing("24px")
            }
            .surface {
                .cardRadius("18px")
                .cardShadow("none")
            }
            .button {
                .radius("999px")
                .secondaryBackground("#eef2ff")
            }
        }

        let rendered = Card {
            Button("Save") {}
        }
        .environment(\.theme, .dark)
        .environment(\.designStyle, style)
        .render()

        #expect(rendered.contains("data-swift-web-ui-theme=\"dark\""))
        #expect(rendered.contains("data-swift-web-ui-design-style=\"brand\""))
        #expect(rendered.contains("[data-swift-web-ui-design-style=\"brand\"]"))
        #expect(rendered.contains("--swui-page-inline-padding: 40px;"))
        #expect(rendered.contains("--swui-stack-spacing: 24px;"))
        #expect(rendered.contains("--swui-card-radius: 18px;"))
        #expect(rendered.contains("--swui-card-shadow: none;"))
        #expect(rendered.contains("--swui-button-radius: 999px;"))
        #expect(rendered.contains("--swui-button-secondary-background: #eef2ff;"))
        #expect(rendered.contains("--swui-field-radius: var(--swui-radius-small);"))
    }

    @Test
    func rendersBuiltInDesignStylePresets() {
        let rendered = Card {
            Badge("Preview")
            ValueDisplay(value: 7)
        }
        .environment(\.theme, .system)
        .environment(\.designStyle, .liquidGlass)
        .render()

        #expect(rendered.contains("data-swift-web-ui-design-style=\"liquid-glass\""))
        #expect(rendered.contains("--swui-card-background: var(--swui-material-glass-background);"))
        #expect(rendered.contains("--swui-card-backdrop-filter: var(--swui-material-glass-backdrop-filter);"))
        #expect(rendered.contains("--swui-button-radius: 999px;"))
        #expect(rendered.contains("--swui-material-glass-backdrop-filter: blur(24px) saturate(1.45);"))
    }

    @Test
    func resolvesButtonTintOnTheButtonElement() {
        let rendered = Card {
            Button("Danger", prominence: .primary) {}
                .tint(.danger)
        }
        .environment(\.theme, .light)
        .environment(\.designStyle, .swiftWeb)
        .render()

        // The design-style token is the plain default; the tint indirection lives
        // in the rule, not in the ancestor-declared token. This is what stops the
        // var(--swui-control-tint, ...) chain from collapsing on the swui-root.
        #expect(rendered.contains("--swui-button-primary-background: var(--swui-accent);"))
        // The primary rule reads the control tint first, so the inline per-button
        // override below resolves on the button element itself.
        #expect(rendered.contains("background: var(--swui-control-tint, var(--swui-button-primary-background));"))
        // The tinted button carries its own --swui-control-tint inline.
        #expect(rendered.contains("style=\"--swui-control-tint: var(--swui-danger)\""))
    }

    @Test
    func mergesClassAndStyleAttributes() {
        let rendered = Card(padding: .small) {
            Text("Body")
        }
        .class("client-counter")
        .style(.minHeight("120px"))
        .padding(.horizontal, .large)
        .render()

        #expect(rendered.contains("class=\"swui-card client-counter\""))
        #expect(rendered.contains("padding: var(--swui-space-sm)"))
        #expect(rendered.contains("min-height: 120px"))
        #expect(rendered.contains("padding-left: var(--swui-space-lg)"))
        #expect(rendered.contains("padding-right: var(--swui-space-lg)"))
    }

    @Test
    func rendersTextAsSemanticElement() {
        let rendered = VStack {
            Text("Page Title", as: .h1)
            Text("Inline value")
                .as(.span)
            Text("Muted caption", as: .small, tone: .muted)
        }
        .render()

        #expect(rendered.contains("<h1 class=\"swui-text\">Page Title</h1>"))
        #expect(rendered.contains("<span class=\"swui-text\">Inline value</span>"))
        #expect(rendered.contains("<small class=\"swui-text swui-text-muted\">Muted caption</small>"))
    }

    @Test
    func rendersFormAndSubmitButtons() {
        let rendered = Form(action: "/counter") {
            LazyHStack {
                SubmitButton("Decrement")
                    .name("delta")
                    .value(-1)
                ValueDisplay(value: 4)
                SubmitButton("Increment")
                    .name("delta")
                    .value(1)
            }
        }
        .render()

        #expect(rendered.contains("<form class=\"swui-form\" action=\"/counter\" method=\"post\">"))
        #expect(rendered.contains("class=\"swui-lazy-hstack\""))
        #expect(rendered.contains("data-swift-web-ui-lazy=\"horizontal\""))
        #expect(rendered.contains("<button class=\"swui-button swui-button-secondary\" type=\"submit\" name=\"delta\" value=\"-1\">Decrement</button>"))
        #expect(rendered.contains("<output class=\"swui-value\" aria-live=\"polite\">4</output>"))
        #expect(rendered.contains("<button class=\"swui-button swui-button-secondary\" type=\"submit\" name=\"delta\" value=\"1\">Increment</button>"))
    }

    @Test
    func rendersButtonsForActions() {
        let rendered = Button(
            "Increment",
            action: .post(
                "/counter",
                name: "delta",
                value: 1
            )
        )
        .render()

        #expect(rendered.contains("<form class=\"swui-form swui-button-action-form\" action=\"/counter\" method=\"post\" data-swift-server-action=\"true\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
        #expect(rendered.contains("class=\"swui-button swui-button-secondary swui-control-regular swui-control-enabled\""))
        #expect(rendered.contains("type=\"submit\""))
        #expect(rendered.contains("data-swift-server-action-button=\"true\""))
    }

    @Test
    func rendersGetActionButtonsWithFields() {
        let rendered = Button(
            "Search",
            action: Action.get(
                "/search",
                fields: [
                    ActionField("q", "swift"),
                ]
            )
        )
        .render()

        #expect(rendered.contains("<form class=\"swui-form swui-button-action-form\" action=\"/search\" method=\"get\" data-swift-server-action=\"true\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"q\" value=\"swift\">"))
        #expect(rendered.contains("type=\"submit\""))
        #expect(!rendered.contains("name=\"_csrf\""))
    }

    @Test
    func rendersActionHiddenFieldsFromEnvironment() {
        var environment = EnvironmentValues()
        environment.actionHiddenFields = [
            ActionField("_csrf", "token"),
        ]

        let rendered = Button(
            "Increment",
            action: .post(
                "/counter",
                name: "delta",
                value: 1
            )
        )
        .render(environment: environment)

        #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"_csrf\" value=\"token\">"))
    }

    @Test
    func rendersButtonsForActionRepresentableValues() {
        let action = Action.post(
            "/counter/increment",
            fields: [
                ActionField("delta", 1),
                ActionField("source", "button"),
            ]
        )
        let rendered = Button("Increment", action: action)
            .render()

        #expect(rendered.contains("<form class=\"swui-form swui-button-action-form\" action=\"/counter/increment\" method=\"post\" data-swift-server-action=\"true\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"source\" value=\"button\">"))
        #expect(rendered.contains("class=\"swui-button swui-button-secondary swui-control-regular swui-control-enabled\""))
        #expect(rendered.contains("data-swift-server-action-button=\"true\""))
    }

    @Test
    func actionButtonsInsideFormsDoNotNestForms() {
        let rendered = Form(action: "/outer") {
            Button(
                "Increment",
                action: .post(
                    "/inner",
                    name: "delta",
                    value: 1
                )
            )
        }
        .render()

        #expect(countOccurrences(of: "<form", in: rendered) == 1)
        #expect(!rendered.contains("swui-button-action-form"))
        #expect(rendered.contains("formaction=\"/inner\""))
        #expect(rendered.contains("formmethod=\"post\""))
        #expect(rendered.contains("name=\"delta\""))
        #expect(rendered.contains("value=\"1\""))
        #expect(rendered.contains("data-swift-server-action-button=\"true\""))
    }

    @Test
    func mutableModifiersApplyWithoutWrapperElements() {
        let rendered = NavigationStack {
            Text("Counter")
                .as(.h1)
                .font(.largeTitle)
                .foregroundStyle(.primary)
                .accessibilityLabel("Counter title")
        }
        .navigationTitle("Counter")
        .render()

        #expect(!rendered.contains("swui-modifier"))
        #expect(rendered.contains("<nav class=\"swui-navigation-stack\""))
        #expect(rendered.contains("data-swui-navigation-title=\"Counter\""))
        #expect(rendered.contains("<h1 class=\"swui-text\""))
        #expect(rendered.contains("font-size: 3rem"))
        #expect(rendered.contains("color: var(--swui-text)"))
        #expect(rendered.contains("aria-label=\"Counter title\""))
    }

    @Test
    func buttonLinksReadButtonEnvironment() {
        let rendered = ButtonLink("Details", href: "/details", prominence: .primary)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accent)
            .disabled()
            .render()

        #expect(rendered.contains("class=\"swui-button swui-button-primary swui-control-large swui-control-disabled\""))
        #expect(rendered.contains("--swui-control-tint: var(--swui-accent)"))
        #expect(rendered.contains("aria-disabled=\"true\""))
        #expect(rendered.contains("tabindex=\"-1\""))
        #expect(rendered.contains("pointer-events: none"))
        #expect(!rendered.contains("href=\"/details\""))
    }

    @Test
    func rendersSwiftUILikeLayoutPrimitives() {
        let rendered = ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading) {
                Section("Inventory") {
                    List {
                        ListRow {
                            Text("First")
                        }
                        ListRow {
                            Text("Second")
                        }
                    }
                }
                Divider()
                ZStack(alignment: .bottomTrailing) {
                    Image("/hero.png")
                    Badge("New")
                }
            }
        }
        .frame(maxHeight: "320px")
        .render()

        #expect(rendered.contains("class=\"swui-scroll-view swui-scroll-view-hidden-indicators swui-fill-v\""))
        #expect(rendered.contains("class=\"swui-lazy-vstack\""))
        #expect(rendered.contains("data-swift-web-ui-lazy=\"vertical\""))
        #expect(rendered.contains("class=\"swui-section swui-fill-h\""))
        #expect(rendered.contains("role=\"list\""))
        #expect(rendered.contains("role=\"listitem\""))
        #expect(rendered.contains("class=\"swui-divider\""))
        #expect(rendered.contains("class=\"swui-zstack\""))
        #expect(rendered.contains("<img class=\"swui-image\" src=\"/hero.png\" alt=\"/hero.png\">"))
        #expect(rendered.contains("max-height: 320px"))
    }

    @Test
    func rendersContentHuggingAndFillSizing() {
        let rendered = HStack(spacing: .small) {
            Badge("hug")
                .fixedSize()
            Badge("fill")
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .render()

        // fixedSize() pins the element to its intrinsic size on both axes
        // (high hugging priority) and blocks upward fill propagation.
        #expect(rendered.contains("class=\"swui-badge swui-hug-h swui-hug-v\""))
        // frame(maxWidth: .infinity) gives low horizontal hugging priority so
        // the element greedily fills the available width.
        #expect(rendered.contains("class=\"swui-badge swui-fill-h\""))
        // Leading alignment within an expanded frame stays axis-neutral
        // (text-align only); child arrangement is owned by the element type.
        #expect(rendered.contains("text-align: left"))
        // Spacer renders as a dedicated flexible gap.
        #expect(rendered.contains("class=\"swui-spacer\""))
    }

    @Test
    func rendersInputControlsWithBindings() {
        @State var title = "Draft"
        @State var secret = "Hidden"
        @State var enabled = true
        @State var status = "published"

        let rendered = VStack {
            TextField("Title", text: $title)
            SecureField("Secret", text: $secret)
                .name("secret")
            Toggle("Enabled", isOn: $enabled)
            Picker("Status", selection: $status) {
                PickerOption("Draft", value: "draft")
                PickerOption("Published", value: "published")
            }
        }
        .render()

        #expect(rendered.contains("class=\"swui-text-field swui-control-regular\""))
        #expect(rendered.contains("type=\"text\""))
        #expect(rendered.contains("value=\"Draft\""))
        #expect(rendered.contains("type=\"password\""))
        #expect(rendered.contains("value=\"Hidden\""))
        #expect(rendered.contains("name=\"secret\""))
        #expect(rendered.contains("class=\"swui-toggle-input\""))
        #expect(rendered.contains("type=\"checkbox\""))
        #expect(rendered.contains("checked"))
        #expect(rendered.contains("<option value=\"draft\">Draft</option>"))
        #expect(rendered.contains("<option value=\"published\" selected>Published</option>"))
    }

    @Test
    func rendersThemeSwitcherWithSelectionBinding() {
        @State var theme = Theme.system

        let rendered = ThemeSwitcher(selection: $theme, themes: [.system, .dark])
            .render()

        #expect(rendered.contains("data-swift-web-ui-theme-option=\"system\""))
        #expect(rendered.contains("data-swift-web-ui-theme-option=\"dark\""))
        #expect(rendered.contains("data-swift-web-ui-theme-selected=\"true\""))
        #expect(rendered.contains("data-swift-web-ui-theme-selected=\"false\""))
        #expect(rendered.contains("role=\"switch\""))
        #expect(rendered.contains("aria-valuetext=\"on\""))
        #expect(rendered.contains("aria-valuetext=\"off\""))
    }

    @Test
    func rendersSwiftUIStyleModifiersNavigationAndAccessibility() {
        @State var count = 2

        let rendered = NavigationStack {
            Text("Counter")
                .as(.h1)
                .font(.largeTitle)
                .foregroundStyle(.primary)
                .accessibilityLabel("Counter title")

            Button("Increment") {}
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accent)
            .accessibilityHint("Adds one")

            Stepper("Count", value: $count, in: 0...10)

            NavigationLink("Details", href: "/details")
        }
        .navigationTitle("Counter")
        .render()

        #expect(rendered.contains("class=\"swui-navigation-stack\""))
        #expect(rendered.contains("data-swui-navigation-title=\"Counter\""))
        #expect(rendered.contains("class=\"swui-button swui-button-primary swui-control-large swui-control-enabled\""))
        #expect(rendered.contains("--swui-control-tint: var(--swui-accent)"))
        #expect(rendered.contains("aria-label=\"Counter title\""))
        #expect(rendered.contains("aria-description=\"Adds one\""))
        #expect(rendered.contains("class=\"swui-stepper swui-control-regular\""))
        #expect(rendered.contains("class=\"swui-navigation-link\""))
    }

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
