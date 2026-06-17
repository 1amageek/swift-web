import Foundation
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
        #expect(rendered.contains("[data-swift-web-ui-style-system=\"swift-web\"]"))
        #expect(rendered.contains("--swui-background: #f7f8fa;"))
        #expect(rendered.contains("--swui-button-radius: var(--swui-radius-medium);"))
        #expect(rendered.contains("class=\"swui-root\""))
        #expect(rendered.contains("data-swift-web-ui-theme=\"system\""))
        #expect(rendered.contains("data-swift-web-ui-style-system=\"swift-web\""))
        #expect(rendered.contains("class=\"swui-page\""))
        #expect(rendered.contains("class=\"swui-card swui-material swui-material-regular client-counter\""))
        #expect(rendered.contains("<output class=\"swui-value\" aria-live=\"polite\">0</output>"))
    }

    @Test
    func rendersDeclarativeStyleSystemBuilderOverrides() {
        let style = StyleSystem(id: "brand") {
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
        .environment(\.styleSystem, style)
        .render()

        #expect(rendered.contains("data-swift-web-ui-theme=\"dark\""))
        #expect(rendered.contains("data-swift-web-ui-style-system=\"brand\""))
        #expect(rendered.contains("[data-swift-web-ui-style-system=\"brand\"]"))
        #expect(rendered.contains("--swui-page-inline-padding: 40px;"))
        #expect(rendered.contains("--swui-stack-spacing: 24px;"))
        #expect(rendered.contains("--swui-card-radius: 18px;"))
        #expect(rendered.contains("--swui-card-shadow: none;"))
        #expect(rendered.contains("--swui-button-radius: 999px;"))
        #expect(rendered.contains("--swui-button-secondary-background: #eef2ff;"))
        #expect(rendered.contains("--swui-field-radius: var(--swui-radius-small);"))
    }

    @Test
    func rendersBuiltInStyleSystemPresets() {
        let rendered = Card {
            Badge("Preview")
            ValueDisplay(value: 7)
        }
        .environment(\.theme, .system)
        .environment(\.styleSystem, .liquidGlass)
        .render()

        #expect(rendered.contains("data-swift-web-ui-style-system=\"liquid-glass\""))
        // The liquid-glass knobs feed the single shared material recipe: a
        // translucent surface tint scaled per level, a wide saturated backdrop
        // blur, and the SVG displacement refraction.
        #expect(rendered.contains("--swui-material-opacity: 0.62;"))
        #expect(rendered.contains("--swui-material-blur: 24px;"))
        #expect(rendered.contains("--swui-material-saturate: 1.6;"))
        #expect(rendered.contains("--swui-material-refraction: url("))
        #expect(rendered.contains("--swui-button-radius: 999px;"))
        // Chrome composes a material level instead of hand-rolling translucency.
        #expect(rendered.contains("class=\"swui-card swui-material swui-material-regular\""))
        #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin\""))
    }

    @Test
    func resolvesButtonTintOnTheButtonElement() {
        let rendered = Card {
            Button("Danger", prominence: .primary) {}
                .tint(.danger)
        }
        .environment(\.theme, .light)
        .environment(\.styleSystem, .swiftWeb)
        .render()

        // The style-system token is the plain default; the tint indirection lives
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

        #expect(rendered.contains("class=\"swui-card swui-material swui-material-regular client-counter\""))
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
        #expect(rendered.contains("<button class=\"swui-button swui-button-secondary swui-material swui-material-thin\" type=\"submit\" name=\"delta\" value=\"-1\">Decrement</button>"))
        #expect(rendered.contains("<output class=\"swui-value\" aria-live=\"polite\">4</output>"))
        #expect(rendered.contains("<button class=\"swui-button swui-button-secondary swui-material swui-material-thin\" type=\"submit\" name=\"delta\" value=\"1\">Increment</button>"))
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
        #expect(rendered.contains("class=\"swui-button swui-button-secondary swui-material swui-material-thin swui-control-regular swui-control-enabled\""))
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
        #expect(rendered.contains("class=\"swui-button swui-button-secondary swui-material swui-material-thin swui-control-regular swui-control-enabled\""))
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
        #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin swui-hug-h swui-hug-v\""))
        // frame(maxWidth: .infinity) gives low horizontal hugging priority so
        // the element greedily fills the available width.
        #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin swui-fill-h\""))
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

        #expect(rendered.contains("class=\"swui-text-field swui-control-regular swui-material swui-material-thin\""))
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

    @Test
    func rendersStatusComponentsComposingMaterial() {
        let rendered = VStack {
            ProgressView("Uploading", value: 0.5)
            ProgressView("Loading")
            Gauge(value: 0.7, label: "CPU")
        }
        .render()

        // Determinate progress lowers to <progress> composing the ultra-thin
        // material; the track tint reads the field background.
        #expect(rendered.contains("class=\"swui-progress\""))
        #expect(rendered.contains("<span class=\"swui-progress-label\">Uploading</span>"))
        #expect(rendered.contains("class=\"swui-progress-bar swui-material swui-material-ultra-thin\""))
        #expect(rendered.contains("--swui-material-tint: var(--swui-field-background)"))
        #expect(rendered.contains("value=\"0.5\""))
        #expect(rendered.contains("max=\"1.0\""))
        // Indeterminate progress lowers to a spinner with progressbar semantics.
        #expect(rendered.contains("class=\"swui-progress-spinner\""))
        #expect(rendered.contains("role=\"progressbar\""))
        #expect(rendered.contains("aria-busy=\"true\""))
        #expect(rendered.contains("aria-label=\"Loading\""))
        // Gauge lowers to <meter> composing the same ultra-thin material.
        #expect(rendered.contains("class=\"swui-gauge\""))
        #expect(rendered.contains("<span class=\"swui-gauge-label\">CPU</span>"))
        #expect(rendered.contains("class=\"swui-gauge-meter swui-material swui-material-ultra-thin\""))
        #expect(rendered.contains("min=\"0.0\""))
        #expect(rendered.contains("value=\"0.7\""))
    }

    @Test
    func rendersDisclosureGroupAndTextEditor() {
        @State var notes = "Hello"

        let rendered = VStack {
            DisclosureGroup("Advanced", isExpanded: true) {
                Text("Body")
            }
            TextEditor(text: $notes)
        }
        .render()

        // DisclosureGroup is a non-replaced surface, so it composes the full
        // regular-material recipe like Card; `isExpanded` emits `open`.
        #expect(rendered.contains("class=\"swui-disclosure-group swui-material swui-material-regular\" open"))
        #expect(rendered.contains("<summary class=\"swui-disclosure-summary\">Advanced</summary>"))
        #expect(rendered.contains("class=\"swui-disclosure-content\""))
        // TextEditor composes the thin material and carries its value as content.
        #expect(rendered.contains("class=\"swui-text-editor swui-material swui-material-thin\""))
        #expect(rendered.contains(">Hello</textarea>"))
    }

    @Test
    func rendersColorPickerAndDatePicker() {
        @State var color = "#3366ff"
        @State var due = Date(timeIntervalSince1970: 0)

        let rendered = VStack {
            ColorPicker("Accent", selection: $color)
            DatePicker("Due", selection: $due)
            DatePicker("Start", selection: $due, displayedComponents: [.date, .hourAndMinute])
            DatePicker("At", selection: $due, displayedComponents: [.hourAndMinute])
        }
        .render()

        // ColorPicker swatch shows the chosen color verbatim — no material.
        #expect(rendered.contains("class=\"swui-field swui-color-picker\""))
        #expect(rendered.contains("<span class=\"swui-field-label\">Accent</span>"))
        #expect(rendered.contains("class=\"swui-color-picker-input\""))
        #expect(rendered.contains("type=\"color\""))
        #expect(rendered.contains("value=\"#3366ff\""))
        // DatePicker composes the thin material and maps components to input type.
        #expect(rendered.contains("class=\"swui-date-picker swui-control-regular swui-material swui-material-thin\""))
        #expect(rendered.contains("type=\"date\""))
        #expect(rendered.contains("type=\"datetime-local\""))
        #expect(rendered.contains("type=\"time\""))
    }

    @Test
    func rendersTextFieldInputTypeAndCanonicalModifiers() {
        @State var email = ""

        let rendered = VStack {
            TextField("Email", text: $email, .type(.email), .required)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .submitLabel(.go)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .render()

        // An explicit `.type(.email)` must replace the default — a duplicate
        // `type` is invalid HTML and the browser would keep the first (`text`).
        #expect(rendered.contains("type=\"email\""))
        #expect(!rendered.contains("type=\"text\""))
        #expect(countOccurrences(of: "type=\"", in: rendered) == 1)
        #expect(rendered.contains("required"))
        // Canonical SwiftUI modifiers lower to the standard form attributes.
        #expect(rendered.contains("inputmode=\"email\""))
        #expect(rendered.contains("autocomplete=\"email\""))
        #expect(rendered.contains("enterkeyhint=\"go\""))
        #expect(rendered.contains("autocapitalize=\"none\""))
        #expect(rendered.contains("autocorrect=\"off\""))
    }

    @Test
    func rendersSegmentedAndInlinePickerStyles() {
        @State var status = "published"
        @State var visibility = "public"

        let rendered = VStack {
            Picker("Status", selection: $status) {
                PickerOption("Draft", value: "draft")
                PickerOption("Published", value: "published")
            }
            .pickerStyle(.segmented)
            Picker("Visibility", selection: $visibility) {
                PickerOption("Public", value: "public")
                PickerOption("Private", value: "private")
            }
            .pickerStyle(.inline)
        }
        .render()

        // The segmented style composes the `bar` material as a radio group.
        #expect(rendered.contains("class=\"swui-picker-segmented swui-control-regular swui-material swui-material-bar\""))
        #expect(rendered.contains("role=\"radiogroup\""))
        #expect(rendered.contains("aria-label=\"Status\""))
        #expect(rendered.contains("class=\"swui-picker-segment\""))
        #expect(rendered.contains("class=\"swui-picker-segment-input\""))
        #expect(rendered.contains("type=\"radio\""))
        // The selected option carries the radio group `name` and `checked`.
        #expect(rendered.contains("name=\"swui-picker-status\""))
        #expect(rendered.contains("value=\"published\" name=\"swui-picker-status\" checked"))
        #expect(rendered.contains("<span class=\"swui-picker-segment-label\">Draft</span>"))
        // The inline style is a plain vertical radio list with no material.
        #expect(rendered.contains("class=\"swui-picker-inline swui-control-regular\""))
        #expect(rendered.contains("name=\"swui-picker-visibility\""))
    }

    @Test
    func rendersMenu() {
        let rendered = Menu("Options") {
            Text("Edit")
            Text("Delete")
        }
        .render()

        #expect(rendered.contains("<details class=\"swui-menu\">"))
        #expect(rendered.contains("class=\"swui-menu-label swui-glass swui-glass-interactive swui-material-regular\""))
        #expect(rendered.contains("class=\"swui-menu-content swui-material swui-material-regular\""))
        #expect(rendered.contains("role=\"menu\""))
    }

    @Test
    func rendersTabView() {
        @State var tab = "home"

        let rendered = TabView(selection: $tab) {
            Tab("Home", value: "home") {
                Text("Home content")
            }
            Tab("Settings", systemImage: "gear", value: "settings") {
                Text("Settings content")
            }
        }
        .render()

        #expect(rendered.contains("class=\"swui-tabview swui-fill-h\""))
        #expect(rendered.contains("role=\"tablist\""))
        #expect(rendered.contains("<div class=\"swui-tab\">"))
        #expect(rendered.contains("class=\"swui-tab-item swui-glass swui-glass-interactive swui-material-regular\""))
        #expect(rendered.contains("role=\"tab\""))
        #expect(rendered.contains("role=\"tabpanel\""))
        #expect(rendered.contains("class=\"swui-tab-input\""))
        #expect(rendered.contains("type=\"radio\""))
        // The selected tab is checked; its radio name is the stable group name.
        #expect(rendered.contains("name=\"swui-tabview-"))
        #expect(rendered.contains("value=\"home\""))
        #expect(rendered.contains("checked"))
        #expect(rendered.contains("<span class=\"swui-tab-item-label\">Home</span>"))
        // The icon variant renders a leading system image.
        #expect(rendered.contains("class=\"swui-tab-item-icon\""))
        #expect(rendered.contains("Home content"))
        #expect(rendered.contains("Settings content"))
    }

    @Test
    func rendersSearchable() {
        @State var query = ""

        let rendered = VStack {
            Text("Items")
        }
        .searchable(text: $query)
        .render()

        #expect(rendered.contains("class=\"swui-searchable swui-fill-h\""))
        #expect(rendered.contains("role=\"search\""))
        #expect(rendered.contains("class=\"swui-search-field swui-material swui-material-thin\""))
        #expect(rendered.contains("type=\"search\""))
        #expect(rendered.contains("placeholder=\"Search\""))
        #expect(rendered.contains("aria-label=\"Search\""))
    }

    @Test
    func rendersPresentedAlertDialog() {
        @State var isPresented = true

        let rendered = Text("Anchor")
            .alert("Delete file?", isPresented: $isPresented) {
                Button("Delete", action: Action.post("/delete"))
            } message: {
                Text("This cannot be undone.")
            }
            .render()

        // The dialog lowers to a native <dialog> composing the thick material.
        #expect(rendered.contains("<dialog class=\"swui-presentation swui-presentation-alert swui-material swui-material-thick\""))
        #expect(rendered.contains("role=\"alertdialog\""))
        // The binding drives the SSR marker and the `open` attribute together.
        #expect(rendered.contains("data-swui-presented=\"true\""))
        #expect(rendered.contains("open"))
        // Every presentation kind light-dismisses on an outside tap; for an
        // alert the backdrop tap is a safe cancel that runs no action.
        #expect(rendered.contains("closedby=\"any\""))
        // The close event syncs the binding back when the dialog is dismissed.
        #expect(rendered.contains("data-swift-event-close="))
        #expect(rendered.contains("class=\"swui-presentation-surface\""))
        #expect(rendered.contains("<h2 class=\"swui-presentation-title\">Delete file?</h2>"))
        // The message wrapper is a flow container so it can legally hold block
        // content such as a Text (which itself lowers to <p>).
        #expect(rendered.contains("<div class=\"swui-presentation-message\"><p class=\"swui-text\">This cannot be undone.</p></div>"))
        #expect(rendered.contains("class=\"swui-presentation-actions\""))
    }

    @Test
    func rendersDismissedSheetWithoutOpenAttribute() {
        @State var isPresented = false

        let rendered = Text("Anchor")
            .sheet(isPresented: $isPresented) {
                Text("Sheet body")
            }
            .render()

        // A dismissed dialog still renders (costing no layout via `display:none`)
        // but carries neither the `open` attribute nor a presented marker.
        #expect(rendered.contains("<dialog class=\"swui-presentation swui-presentation-sheet swui-material swui-material-thick\""))
        #expect(rendered.contains("role=\"dialog\""))
        #expect(rendered.contains("data-swui-presented=\"false\""))
        #expect(!rendered.contains(" open"))
        // Sheets and popovers dismiss on any light-dismiss gesture.
        #expect(rendered.contains("closedby=\"any\""))
        #expect(rendered.contains("Sheet body"))
    }

    @Test
    func rendersConfirmationDialogTitleVisibility() {
        @State var isPresented = true

        // Without a message, `automatic` hides the title (matching SwiftUI), so
        // only an explicit `.visible` shows it.
        let hidden = Text("Anchor")
            .confirmationDialog("Choose", isPresented: $isPresented) {
                Button("Option", action: Action.post("/x"))
            }
            .render()
        #expect(hidden.contains("swui-presentation-confirmation"))
        #expect(!hidden.contains("swui-presentation-title"))

        let shown = Text("Anchor")
            .confirmationDialog("Choose", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Option", action: Action.post("/x"))
            }
            .render()
        #expect(shown.contains("<h2 class=\"swui-presentation-title\">Choose</h2>"))
    }

    @Test
    func interactiveDismissDisabledForcesExplicitChoice() {
        @State var isPresented = true

        // By default an alert light-dismisses on a backdrop tap or Esc.
        let dismissable = Text("Anchor")
            .alert("Delete this draft?", isPresented: $isPresented) {
                Button("Delete", action: Action.post("/delete"))
            }
            .render()
        #expect(dismissable.contains("closedby=\"any\""))

        // Applying `interactiveDismissDisabled()` outside the presentation flows
        // the opt-out down through the environment, so the dialog renders
        // `closedby="none"` — neither the backdrop nor Esc can dismiss it and
        // only the binding (a button that flips it) closes the dialog.
        let locked = Text("Anchor")
            .alert("Delete this draft?", isPresented: $isPresented) {
                Button("Delete", action: Action.post("/delete"))
            }
            .interactiveDismissDisabled()
            .render()
        #expect(locked.contains("closedby=\"none\""))
        #expect(!locked.contains("closedby=\"any\""))

        // Passing `false` restores the default light dismissal.
        let reenabled = Text("Anchor")
            .alert("Delete this draft?", isPresented: $isPresented) {
                Button("Delete", action: Action.post("/delete"))
            }
            .interactiveDismissDisabled(false)
            .render()
        #expect(reenabled.contains("closedby=\"any\""))
        #expect(!reenabled.contains("closedby=\"none\""))
    }

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
