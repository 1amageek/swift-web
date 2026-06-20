import Foundation
import SwiftHTML
import SwiftWebUI
import Synchronization
import Testing

@Suite
struct SwiftWebUIRenderingTests {
  @Test
  func rendersThemeAndLayoutPrimitives() {
    let rendered = main {
      VStack(spacing: .large) {
        VStack(spacing: .small) {
          Badge("SwiftWeb")
          Heading("Counter", level: .page)
          Text("Client and server counters.", tone: .muted)
        }
        Grid {
          GroupBox {
            Heading("Client Counter")
            Text("Runs in WASM.", tone: .muted)
            Text("0", as: .strong)
              .accessibilityIdentifier("counter-value")
          }
          .accessibilityIdentifier("client-counter")
        }
      }
    }
    .environment(\.theme, .system)
    .render()

    #expect(rendered.contains("[data-theme=\"system\"]"))
    #expect(rendered.contains("[data-style-system=\"swift-web\"]"))
    #expect(rendered.contains("--swui-background: #f7f8fa;"))
    #expect(rendered.contains("--swui-button-radius: var(--swui-radius-medium);"))
    #expect(rendered.contains(".swui-code-line-number"))
    #expect(rendered.contains("white-space: nowrap;"))
    #expect(rendered.contains(".swui-list-row .swui-text"))
    #expect(rendered.contains(".swui-list-row .swui-text-muted"))
    #expect(rendered.contains("class=\"swui-root\""))
    #expect(rendered.contains("data-theme=\"system\""))
    #expect(rendered.contains("data-style-system=\"swift-web\""))
    #expect(
      rendered.contains("class=\"swui-group-box swui-material swui-material-regular\""))
    #expect(rendered.contains("data-accessibility-identifier=\"client-counter\""))
    #expect(rendered.contains("data-accessibility-identifier=\"counter-value\""))
  }

  @Test
  func rendersDeclarativeStyleSystemBuilderOverrides() {
    let style = StyleSystem(id: "brand") {
      .root {
        .pageInlinePadding("40px")
          .stackSpacing("24px")
      }
      .surface {
        .containerRadius("18px")
          .containerShadow("none")
      }
      .button {
        .radius("999px")
          .secondaryBackground("#eef2ff")
      }
    }

    let rendered = GroupBox {
      Button("Save") {}
    }
    .environment(\.theme, .dark)
    .environment(\.styleSystem, style)
    .render()

    #expect(rendered.contains("data-theme=\"dark\""))
    #expect(rendered.contains("data-style-system=\"brand\""))
    #expect(rendered.contains("[data-style-system=\"brand\"]"))
    #expect(rendered.contains("--swui-page-inline-padding: 40px;"))
    #expect(rendered.contains("--swui-stack-spacing: 24px;"))
    #expect(rendered.contains("--swui-container-radius: 18px;"))
    #expect(rendered.contains("--swui-container-shadow: none;"))
    #expect(rendered.contains("--swui-button-radius: 999px;"))
    #expect(rendered.contains("--swui-button-secondary-background: #eef2ff;"))
    #expect(rendered.contains("--swui-field-radius: var(--swui-radius-medium);"))
  }

  @Test
  func rendersBuiltInStyleSystemPresets() {
    let rendered = GroupBox {
      Badge("Preview")
      Text("7", as: .strong)
    }
    .environment(\.theme, .system)
    .environment(\.styleSystem, .liquidGlass)
    .render()

    #expect(rendered.contains("data-style-system=\"liquid-glass\""))
    // The liquid-glass knobs feed the single shared material recipe: a
    // translucent surface tint scaled per level, a wide saturated backdrop
    // blur, and the SVG displacement refraction.
    #expect(rendered.contains("--swui-material-opacity: 0.62;"))
    #expect(rendered.contains("--swui-material-blur: 24px;"))
    #expect(rendered.contains("--swui-material-saturate: 1.6;"))
    #expect(rendered.contains("--swui-material-refraction: url("))
    #expect(rendered.contains("--swui-button-radius: 999px;"))
    // Chrome composes a material level instead of hand-rolling translucency.
    #expect(rendered.contains("class=\"swui-group-box swui-material swui-material-regular\""))
    #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin\""))
  }

  @Test
  func resolvesButtonTintOnTheButtonElement() {
    let rendered = GroupBox {
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
    #expect(
      rendered.contains(
        "background: var(--swui-control-tint, var(--swui-button-primary-background));"))
    // The tinted button carries its own --swui-control-tint inline.
    #expect(rendered.contains("style=\"--swui-control-tint: var(--swui-danger)\""))
  }

  @Test
  func mergesClassAndStyleAttributes() {
    let rendered = GroupBox {
      Text("Body")
    }
    .accessibilityIdentifier("client-counter")
    .style(.minHeight("120px"))
    .padding(.small)
    .padding(.horizontal, .large)
    .padding(.vertical, .xlarge)
    .render()

    #expect(
      rendered.contains("class=\"swui-group-box swui-material swui-material-regular\""))
    #expect(rendered.contains("data-accessibility-identifier=\"client-counter\""))
    #expect(rendered.contains("padding: var(--swui-space-sm)"))
    #expect(rendered.contains("min-height: 120px"))
    #expect(rendered.contains("padding-left: var(--swui-space-lg)"))
    #expect(rendered.contains("padding-right: var(--swui-space-lg)"))
    #expect(rendered.contains("padding-top: var(--swui-space-xl)"))
    #expect(rendered.contains("padding-bottom: var(--swui-space-xl)"))
  }

  @Test
  func rendersGridSystemWithPageInset() {
    let rendered = GridSystem {
      Pane(span: 12) {
        Text("Body")
      }
    }
    .frame(maxWidth: 720)
    .render()

    #expect(rendered.contains("class=\"swui-frame swui-fill-h\""))
    #expect(rendered.contains("class=\"swui-grid-system\""))
    #expect(rendered.contains("--swui-grid-system-columns: 12"))
    #expect(rendered.contains("--swui-grid-system-gutter: var(--swui-space-lg)"))
    #expect(rendered.contains("max-width: 720px"))
    #expect(rendered.contains("padding-block: var(--swui-space-xl)"))
    #expect(rendered.contains("padding-inline: var(--swui-page-inline-padding);"))
    #expect(rendered.contains("class=\"swui-grid-pane\""))
    #expect(rendered.contains("grid-column: span 12"))
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
  func rendersCodeBlockWithLineNumbers() {
    let rendered = CodeBlock(
      """
      let title = "<main>"

      Text(title, as: .code)
      """,
      language: "swift",
      startLine: 12
    )
    .render()

    #expect(rendered.contains("<pre class=\"swui-code-block\" role=\"region\" aria-label=\"swift code block\">"))
    #expect(rendered.contains("<code class=\"swui-code-block-content\" data-language=\"swift\">"))
    #expect(rendered.contains("<span class=\"swui-code-line\" data-line=\"12\">"))
    #expect(rendered.contains("<span class=\"swui-code-line-number\" aria-hidden=\"true\">12</span>"))
    #expect(rendered.contains("<span class=\"swui-code-line-content\">let title = \"&lt;main&gt;\"</span>"))
    #expect(rendered.contains("<span class=\"swui-code-line\" data-line=\"13\">"))
    #expect(rendered.contains("<span class=\"swui-code-line-content\"></span>"))
    #expect(rendered.contains("<span class=\"swui-code-line-number\" aria-hidden=\"true\">14</span>"))
  }

  @Test
  func rendersInlineCodeWithCodeStyling() {
    let rendered = Text("inline.code()", as: .code).render()

    #expect(rendered.contains("<code class=\"swui-text swui-inline-code\">inline.code()</code>"))
  }

  @Test
  func rendersFormAndSubmitButtons() {
    let rendered = Form(action: "/counter") {
      LazyHStack {
        SubmitButton("Decrement")
          .name("delta")
          .value(-1)
        Text("4", as: .strong)
          .accessibilityIdentifier("counterValue")
        SubmitButton("Increment")
          .name("delta")
          .value(1)
      }
    }
    .render()

    #expect(rendered.contains("<form class=\"swui-form\" action=\"/counter\" method=\"post\">"))
    #expect(rendered.contains("class=\"swui-lazy-hstack\""))
    #expect(rendered.contains("data-lazy=\"horizontal\""))
    #expect(
      rendered.contains(
        "<button class=\"swui-button swui-button-secondary swui-material swui-material-thin\" type=\"submit\" name=\"delta\" value=\"-1\">Decrement</button>"
      ))
    #expect(rendered.contains("data-accessibility-identifier=\"counterValue\""))
    #expect(
      rendered.contains(
        "<button class=\"swui-button swui-button-secondary swui-material swui-material-thin\" type=\"submit\" name=\"delta\" value=\"1\">Increment</button>"
      ))
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

    #expect(
      rendered.contains(
        "<form class=\"swui-form swui-button-action-form\" action=\"/counter\" method=\"post\" data-server-action=\"true\">"
      ))
    #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
    #expect(
      rendered.contains(
        "class=\"swui-button swui-button-secondary swui-material swui-material-thin swui-control-regular swui-control-enabled\""
      ))
    #expect(rendered.contains("type=\"submit\""))
    #expect(rendered.contains("data-server-action-button=\"true\""))
  }

  @Test
  func rendersGetActionButtonsWithFields() {
    let rendered = Button(
      "Search",
      action: Action.get(
        "/search",
        fields: [
          ActionField("q", "swift")
        ]
      )
    )
    .render()

    #expect(
      rendered.contains(
        "<form class=\"swui-form swui-button-action-form\" action=\"/search\" method=\"get\" data-server-action=\"true\">"
      ))
    #expect(rendered.contains("<input type=\"hidden\" name=\"q\" value=\"swift\">"))
    #expect(rendered.contains("type=\"submit\""))
    #expect(!rendered.contains("name=\"_csrf\""))
  }

  @Test
  func rendersActionHiddenFieldsFromEnvironment() {
    var environment = EnvironmentValues()
    environment.actionHiddenFields = [
      ActionField("_csrf", "token")
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

    #expect(
      rendered.contains(
        "<form class=\"swui-form swui-button-action-form\" action=\"/counter/increment\" method=\"post\" data-server-action=\"true\">"
      ))
    #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
    #expect(rendered.contains("<input type=\"hidden\" name=\"source\" value=\"button\">"))
    #expect(
      rendered.contains(
        "class=\"swui-button swui-button-secondary swui-material swui-material-thin swui-control-regular swui-control-enabled\""
      ))
    #expect(rendered.contains("data-server-action-button=\"true\""))
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
    #expect(rendered.contains("data-server-action-button=\"true\""))
  }

  @Test
  func swiftUIModifiersRenderAsWrapperGraph() {
    let rendered = NavigationStack {
      Text("Counter")
        .as(.h1)
        .font(.largeTitle)
        .foregroundStyle(.primary)
        .accessibilityLabel("Counter title")
    }
    .navigationTitle("Counter")
    .render()

    #expect(rendered.contains("swui-modifier"))
    #expect(rendered.contains("swui-semantic-modifier"))
    #expect(rendered.contains("swui-text-style-modifier"))
    #expect(rendered.contains("swui-style-foreground"))
    #expect(rendered.contains("<nav class=\"swui-navigation-stack\""))
    #expect(rendered.contains("data-navigation-title=\"Counter\""))
    #expect(rendered.contains("<h1 class=\"swui-text\""))
    #expect(rendered.contains("font-size: 3rem"))
    #expect(rendered.contains("color: var(--swui-text)"))
    #expect(rendered.contains("aria-label=\"Counter title\""))
  }

  @Test
  func linksCanReadButtonStyleEnvironment() {
    let rendered = Link("Details", href: "/details")
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(.accent)
      .disabled()
      .render()

    #expect(
      rendered.contains(
        "class=\"swui-button swui-button-primary swui-control-large swui-control-disabled\""))
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
    .frame(maxHeight: 320)
    .render()

    #expect(rendered.contains("class=\"swui-frame swui-fill-v\""))
    #expect(rendered.contains("class=\"swui-scroll-view swui-scroll-view-hidden-indicators\""))
    #expect(rendered.contains("class=\"swui-lazy-vstack\""))
    #expect(rendered.contains("data-lazy=\"vertical\""))
    #expect(rendered.contains("class=\"swui-section swui-fill-h\""))
    #expect(rendered.contains("role=\"list\""))
    #expect(rendered.contains("role=\"listitem\""))
    #expect(rendered.contains("class=\"swui-divider\""))
    #expect(rendered.contains("class=\"swui-zstack\""))
    #expect(rendered.contains("<img class=\"swui-image\" src=\"/hero.png\" alt=\"/hero.png\">"))
    #expect(rendered.contains("max-height: 320px"))
  }

  @Test
  func rendersSwiftUILikeLayoutModifierSurface() {
    let rendered = Text("Layout")
      .padding(.horizontal, 12)
      .padding(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4))
      .frame(
        minWidth: 80,
        idealWidth: 120,
        maxWidth: .infinity,
        minHeight: 24,
        idealHeight: 48,
        maxHeight: 96,
        alignment: .topLeading
      )
      .offset(x: 4, y: 8)
      .position(CGPoint(x: 24, y: 36))
      .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 8, alignment: .leading)
      .alignmentGuide(.leading) { _ in 7 }
      .render()

    #expect(rendered.contains("padding-left: 12px"))
    #expect(rendered.contains("padding-right: 12px"))
    #expect(rendered.contains("padding: 1px 4px 3px 2px"))
    #expect(rendered.contains("min-width: 80px"))
    #expect(rendered.contains("--swui-ideal-width: 120px"))
    #expect(rendered.contains("--swui-ideal-height: 48px"))
    #expect(rendered.contains("max-height: 96px"))
    #expect(rendered.contains("transform: translate(4px, 8px)"))
    #expect(rendered.contains("position: absolute"))
    #expect(rendered.contains("left: 24px"))
    #expect(rendered.contains("top: 36px"))
    #expect(rendered.contains("calc((100% - 2 * 8px) / 3)"))
    #expect(rendered.contains("data-alignment-guide-horizontal=\"leading\""))
    #expect(rendered.contains("--swui-alignment-guide-horizontal: 7px"))
  }

  @Test
  func rendersSafeAreaModifiers() {
    let rendered = VStack {
      Text("Safe")
    }
    .ignoresSafeArea(.container, edges: [.top, .bottom])
    .safeAreaPadding(.horizontal, 16)
    .safeAreaInset(edge: VerticalEdge.top, spacing: 4) {
      Text("Inset")
    }
    .render()

    #expect(rendered.contains("class=\"swui-safe-area-inset swui-safe-area-inset-top\""))
    #expect(rendered.contains("class=\"swui-safe-area-inset-content\""))
    #expect(rendered.contains("data-safe-area-regions=\"container\""))
    #expect(rendered.contains("margin-top: calc(env(safe-area-inset-top) * -1)"))
    #expect(rendered.contains("padding-bottom: env(safe-area-inset-bottom)"))
    #expect(rendered.contains("padding-left: calc(env(safe-area-inset-left) + 16px)"))
    #expect(rendered.contains("gap: 4px"))

    let paddedInsets = Text("Insets")
      .safeAreaPadding(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4))
      .render()

    #expect(paddedInsets.contains("padding-top: calc(env(safe-area-inset-top) + 1px)"))
    #expect(paddedInsets.contains("padding-left: calc(env(safe-area-inset-left) + 2px)"))
    #expect(paddedInsets.contains("padding-bottom: calc(env(safe-area-inset-bottom) + 3px)"))
    #expect(paddedInsets.contains("padding-right: calc(env(safe-area-inset-right) + 4px)"))
  }

  @Test
  func rendersSwiftUILikeAppearanceModifiers() {
    let styles = Text("Appearance")
      .background(.accent)
      .overlay(.primary)
      .render()
    let shapedEnvironmentBackground = Text("Shape")
      .background(ColorSchemeShapeStyle(), in: .rect(cornerRadius: 6))
      .environment(\.colorScheme, .dark)
      .render()
    let layers = Text("Layered")
      .background(alignment: .topLeading) {
        Text("Background")
      }
      .overlay(alignment: .bottomTrailing) {
        Text("Overlay")
      }
      .render()
    let shape = Text("Shape")
      .clipShape(.capsule)
      .clipped()
      .opacity(0.5)
      .shadow(radius: 4, x: 1, y: 2)
      .render()
    let filters = Text("Filters")
      .blur(radius: 3)
      .brightness(0.2)
      .contrast(1.2)
      .saturation(0.8)
      .grayscale(0.4)
      .hueRotation(.degrees(30))
      .colorInvert()
      .render()
    let compositing = Text("Compositing")
      .colorMultiply("#ff0000")
      .blendMode(.multiply)
      .rotationEffect(.degrees(10), anchor: .topLeading)
      .scaleEffect(x: 2, y: 3, anchor: .bottomTrailing)
      .allowsHitTesting(false)
      .compositingGroup()
      .drawingGroup(colorMode: .linear)
      .render()
    let rendered = styles + layers + shape + filters + compositing

    #expect(rendered.contains("swui-style-background"))
    #expect(rendered.contains("swui-style-overlay"))
    #expect(styles.contains("margin-top: calc(env(safe-area-inset-top) * -1)"))
    #expect(styles.contains("padding-right: env(safe-area-inset-right)"))
    #expect(shapedEnvironmentBackground.contains("background: #111111"))
    #expect(shapedEnvironmentBackground.contains("border-radius: 6px"))
    #expect(rendered.contains("class=\"swui-layered swui-background-layered\""))
    #expect(rendered.contains("class=\"swui-layered swui-overlay-layered\""))
    #expect(rendered.contains("border-radius: var(--swui-radius-pill)"))
    #expect(rendered.contains("overflow: hidden"))
    #expect(rendered.contains("opacity: 0.5"))
    #expect(rendered.contains("box-shadow: 1px 2px 4px rgba(0, 0, 0, 0.33)"))
    #expect(rendered.contains("filter: blur(3px)"))
    #expect(rendered.contains("filter: brightness(1.2)"))
    #expect(rendered.contains("filter: contrast(1.2)"))
    #expect(rendered.contains("filter: saturate(0.8)"))
    #expect(rendered.contains("filter: grayscale(0.4)"))
    #expect(rendered.contains("filter: hue-rotate(30deg)"))
    #expect(rendered.contains("filter: invert(1)"))
    #expect(rendered.contains("background-color: #ff0000"))
    #expect(rendered.contains("mix-blend-mode: multiply"))
    #expect(rendered.contains("transform: rotate(10deg)"))
    #expect(rendered.contains("transform: scale(2, 3)"))
    #expect(rendered.contains("pointer-events: none"))
    #expect(rendered.contains("isolation: isolate"))
    #expect(rendered.contains("data-drawing-group=\"linear\""))
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

    // fixedSize() is a SwiftUI-style modifier wrapper. The sizing intent
    // belongs to the modifier node rather than the leaf component.
    #expect(
      rendered.contains(
        "class=\"swui-modifier swui-attribute swui-box-modifier swui-hug-h swui-hug-v\""))
    // frame(maxWidth: .infinity) creates an outer frame that owns fill intent.
    #expect(rendered.contains("class=\"swui-frame swui-fill-h\""))
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

    #expect(
      rendered.contains(
        "class=\"swui-text-field swui-control-regular swui-material swui-material-thin\""))
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

    #expect(rendered.contains("swui-picker-segmented"))
    #expect(rendered.contains("role=\"radiogroup\""))
    #expect(rendered.contains("aria-label=\"Appearance\""))
    #expect(rendered.contains("data-theme-option=\"system\""))
    #expect(rendered.contains("data-theme-option=\"dark\""))
    #expect(rendered.contains("type=\"radio\""))
    #expect(rendered.contains("value=\"system\""))
    #expect(rendered.contains("name=\"swui-picker-appearance\" checked"))
    #expect(rendered.contains("value=\"dark\""))
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
    #expect(rendered.contains("data-navigation-title=\"Counter\""))
    #expect(
      rendered.contains(
        "class=\"swui-button swui-button-primary swui-control-large swui-control-enabled\""))
    #expect(rendered.contains("--swui-control-tint: var(--swui-accent)"))
    #expect(rendered.contains("aria-label=\"Counter title\""))
    #expect(rendered.contains("aria-description=\"Adds one\""))
    #expect(
      rendered.contains(
        "class=\"swui-stepper swui-control-regular swui-control-enabled\""))
    #expect(rendered.contains("role=\"group\" aria-label=\"Count\""))
    #expect(rendered.contains("class=\"swui-stepper-value val\" aria-live=\"polite\""))
    #expect(rendered.contains("class=\"swui-stepper-button\" aria-label=\"Decrement Count\""))
    #expect(rendered.contains("class=\"swui-stepper-button\" aria-label=\"Increment Count\""))
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
    // regular-material recipe; `isExpanded` emits `open`.
    #expect(
      rendered.contains("class=\"swui-disclosure-group swui-material swui-material-regular\" open"))
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
    #expect(
      rendered.contains(
        "class=\"swui-date-picker swui-control-regular swui-material swui-material-thin\""))
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
  func rendersSwiftUILikeTextModifiers() {
    let typography = Text("Title")
      .font(.title)
      .fontWeight(.semibold)
      .fontDesign(.rounded)
      .bold(false)
      .italic()
      .monospaced(false)
      .render()
    let wrapping = Text("Wrapping")
      .lineLimit(2)
      .lineSpacing(4)
      .multilineTextAlignment(.center)
      .truncationMode(.tail)
      .allowsTightening(false)
      .minimumScaleFactor(0.8)
      .render()
    let transforms = Text("Transform")
      .textCase(.uppercase)
      .fontWidth(.expanded)
      .kerning(1)
      .tracking(2)
      .baselineOffset(3)
      .render()
    let decorations = Text("Decoration")
      .underline(pattern: .dash, color: "red")
      .strikethrough(pattern: .dot, color: "blue")
      .textSelection(.enabled)
      .render()
    let hierarchicalForeground = Text("Hierarchy")
      .foregroundStyle(.primary, .secondary, .accent)
      .render()
    let rendered = typography + wrapping + transforms + decorations + hierarchicalForeground

    #expect(rendered.contains("font-size: 2rem"))
    #expect(rendered.contains("font-weight: 600"))
    #expect(rendered.contains("SF Pro Rounded"))
    #expect(rendered.contains("font-style: italic"))
    #expect(rendered.contains("-webkit-line-clamp: 2"))
    #expect(rendered.contains("--swui-line-spacing: 4px"))
    #expect(rendered.contains("text-align: center"))
    #expect(rendered.contains("text-overflow: ellipsis"))
    #expect(rendered.contains("font-kerning: none"))
    #expect(rendered.contains("--swui-minimum-scale-factor: 0.8"))
    #expect(rendered.contains("text-transform: uppercase"))
    #expect(rendered.contains("font-stretch: 112.5%"))
    #expect(rendered.contains("letter-spacing: 1px"))
    #expect(rendered.contains("letter-spacing: 2px"))
    #expect(rendered.contains("vertical-align: 3px"))
    #expect(rendered.contains("text-decoration-style: dashed"))
    #expect(rendered.contains("text-decoration-color: red"))
    #expect(rendered.contains("text-decoration-style: dotted"))
    #expect(rendered.contains("text-decoration-color: blue"))
    #expect(rendered.contains("user-select: text"))
    #expect(rendered.contains("--swui-foreground-primary: var(--swui-text)"))
    #expect(rendered.contains("--swui-foreground-secondary: var(--swui-text-muted)"))
    #expect(rendered.contains("--swui-foreground-tertiary: var(--swui-accent)"))
  }

  @Test
  func rendersControlStyleEnvironmentModifiers() {
    @State var title = "Draft"
    @State var enabled = true
    @State var tab = "home"

    let rendered = VStack {
      TextField("Title", text: $title)
      Toggle("Enabled", isOn: $enabled)
      Label("Favorite", systemImage: "star")
      List {
        ListRow {
          Text("Row")
        }
      }
      Form(action: "/nested") {
        TextField("Nested", text: $title)
      }
      Menu("Options") {
        Text("Edit")
      }
      ProgressView("Loading", value: 0.4)
      Gauge(value: 0.7, label: "CPU")
      TabView(selection: $tab) {
        Tab("Home", value: "home") {
          Text("Home")
        }
      }
    }
    .textFieldStyle(.plain)
    .toggleStyle(.checkbox)
    .labelStyle(.iconOnly)
    .listStyle(.grouped)
    .formStyle(.columns)
    .menuStyle(.button)
    .progressViewStyle(.linear)
    .gaugeStyle(.accessoryLinear)
    .tabViewStyle(.page)
    .render()

    #expect(rendered.contains("swui-text-field-style-plain"))
    #expect(rendered.contains("swui-toggle-style-checkbox"))
    #expect(rendered.contains("swui-label-style-iconOnly"))
    #expect(rendered.contains("swui-list-style-grouped"))
    #expect(rendered.contains("swui-form-style-columns"))
    #expect(rendered.contains("swui-menu-style-button"))
    #expect(rendered.contains("swui-progress-style-linear"))
    #expect(rendered.contains("swui-gauge-style-accessoryLinear"))
    #expect(rendered.contains("swui-tabview-style-page"))
  }

  @Test
  func rendersFormEventAndFocusModifiers() {
    @State var title = "Draft"
    @FocusState var focused = false

    let rendered = Form(action: "/submit") {
      TextField("Title", text: $title)
        .textContentType(.name)
        .submitLabel(.done)
        .onSubmit {}
        .focused($focused)
    }
    .onSubmit(of: .all) {}
    .submitScope(false)
    .focusable()
    .onChange(of: title, initial: true) { _ in }
    .render()

    #expect(rendered.contains("autocomplete=\"name\""))
    #expect(rendered.contains("enterkeyhint=\"done\""))
    #expect(rendered.contains("data-event-submit="))
    #expect(rendered.contains("data-event-focus="))
    #expect(rendered.contains("data-event-blur="))
    #expect(rendered.contains("data-submit-triggers=\"all\""))
    #expect(rendered.contains("data-submit-scope=\"nonblocking\""))
    #expect(rendered.contains("tabindex=\"0\""))
    #expect(rendered.contains("data-focusable=\"true\""))
    #expect(rendered.contains("data-change-observer=\"value\""))
    #expect(rendered.contains("data-change-initial=\"true\""))
  }

  @Test
  func onChangeInvokesInitialAndChangedValues() throws {
    let recorder = ChangeRecorder<Int>()
    let store = StateStore()

    let first = OnChangeProbe(value: 1, recorder: recorder)
      .renderArtifact(stateStore: store)
    #expect(recorder.records == [ChangeRecord(oldValue: 1, newValue: 1)])
    #expect(try store.snapshot(schemaHash: first.hydration.stateSchemaHash).values.count == 1)

    _ = OnChangeProbe(value: 1, recorder: recorder)
      .renderArtifact(stateStore: store)
    #expect(recorder.records == [ChangeRecord(oldValue: 1, newValue: 1)])

    _ = OnChangeProbe(value: 3, recorder: recorder)
      .renderArtifact(stateStore: store)
    #expect(recorder.records == [
      ChangeRecord(oldValue: 1, newValue: 1),
      ChangeRecord(oldValue: 1, newValue: 3),
    ])
  }

  @Test
  func focusedEqualsClearsOptionalFocusState() throws {
    @State var title = ""
    @FocusState var focusedField: FocusField?

    let artifact = TextField("Title", text: $title)
      .focused($focusedField, equals: .title)
      .renderArtifact()

    let focusIn = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "focusin" })
    let focusOut = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "focusout" })

    focusIn.invoke()
    #expect(focusedField == .title)

    focusOut.invoke()
    #expect(focusedField == nil)
  }

  @Test
  func rendersLifecycleAndGestureEventModifiers() {
    let lifecycle = Text("Lifecycle")
      .onAppear {}
      .onDisappear {}
      .task(id: "profile") {}
      .render()
    let gestures = Text("Gestures")
      .onTapGesture(count: 2) {}
      .onLongPressGesture(minimumDuration: 0.75, maximumDistance: 12, pressing: { _ in }) {}
      .render()
    let hover = Text("Hover")
      .onHover { _ in }
      .onContinuousHover(coordinateSpace: .global) { _ in }
      .help("Help text")
      .render()
    let rendered = lifecycle + gestures + hover

    #expect(rendered.contains("data-lifecycle=\"appear\""))
    #expect(rendered.contains("data-lifecycle=\"disappear\""))
    #expect(rendered.contains("data-task=\"true\""))
    #expect(rendered.contains("data-task-id=\"profile\""))
    #expect(rendered.contains("data-event-appear="))
    #expect(rendered.contains("data-event-disappear="))
    #expect(rendered.contains("data-tap-count=\"2\""))
    #expect(rendered.contains("data-event-click="))
    #expect(rendered.contains("data-long-press-minimum-duration=\"0.75\""))
    #expect(rendered.contains("data-long-press-maximum-distance=\"12px\""))
    #expect(rendered.contains("data-event-pointerdown="))
    #expect(rendered.contains("data-event-pointerup="))
    #expect(rendered.contains("data-event-mouseenter="))
    #expect(rendered.contains("data-event-mouseleave="))
    #expect(rendered.contains("data-event-mousemove="))
    #expect(rendered.contains("data-hover-coordinate-space=\"global\""))
    #expect(rendered.contains("title=\"Help text\""))
    #expect(rendered.contains("aria-description=\"Help text\""))
  }

  @Test
  func rendersRawDOMEventModifiersOnAttributeMutableComponents() {
    @State var title = "Draft"

    let rendered = TextField("Title", text: $title)
      .onKeyDown { _ in }
      .onKeyUp { _ in }
      .onFocus { _ in }
      .onBlur { _ in }
      .onMouseDown { _ in }
      .onMouseUp { _ in }
      .onPointerMove { _ in }
      .onDragStart { _ in }
      .onDragOver { _ in }
      .onDrop { _ in }
      .onInvalid { _ in }
      .onScroll { _ in }
      .render()

    #expect(rendered.contains("data-event-keydown="))
    #expect(rendered.contains("data-event-keyup="))
    #expect(rendered.contains("data-event-focus="))
    #expect(rendered.contains("data-event-blur="))
    #expect(rendered.contains("data-event-mousedown="))
    #expect(rendered.contains("data-event-mouseup="))
    #expect(rendered.contains("data-event-pointermove="))
    #expect(rendered.contains("data-event-dragstart="))
    #expect(rendered.contains("data-event-dragover="))
    #expect(rendered.contains("data-event-drop="))
    #expect(rendered.contains("data-event-invalid="))
    #expect(rendered.contains("data-event-scroll="))
  }

  @Test
  func rendersSwiftUILikeAccessibilityMetadataModifiers() {
    let labels = Text("Accessible")
      .accessibilityIdentifier("save-button")
      .accessibilityLabel("Save", isEnabled: true)
      .accessibilityHint("Stores the draft", isEnabled: true)
      .accessibilityValue("Ready", isEnabled: true)
      .accessibilityHidden(false)
      .accessibilityInputLabels(["Save", "Store"])
      .render()
    let traits = Text("Traits")
      .accessibilityAddTraits([.isButton, .isSelected, .isModal])
      .accessibilityRemoveTraits(.isImage)
      .accessibilityElement(children: .combine)
      .accessibilitySortPriority(3)
      .accessibilityHeading(.h2)
      .render()
    let rendered = labels + traits

    #expect(rendered.contains("data-accessibility-identifier=\"save-button\""))
    #expect(rendered.contains("aria-label=\"Save\""))
    #expect(rendered.contains("aria-description=\"Stores the draft\""))
    #expect(rendered.contains("aria-valuetext=\"Ready\""))
    #expect(rendered.contains("aria-hidden=\"false\""))
    #expect(rendered.contains("data-accessibility-input-labels=\"Save|Store\""))
    #expect(rendered.contains("data-accessibility-add-traits=\"isButton isSelected isModal\""))
    #expect(rendered.contains("role=\"button\""))
    #expect(rendered.contains("aria-selected=\"true\""))
    #expect(rendered.contains("aria-modal=\"true\""))
    #expect(rendered.contains("data-accessibility-remove-traits=\"isImage\""))
    #expect(rendered.contains("data-accessibility-child-behavior=\"combine\""))
    #expect(rendered.contains("data-accessibility-sort-priority=\"3\""))
    #expect(rendered.contains("role=\"heading\""))
    #expect(rendered.contains("aria-level=\"2\""))
  }

  @Test
  func rendersSwiftUILikeAccessibilityActionModifiers() {
    let actions = Text("Action")
      .accessibilityAction(.default) {}
      .accessibilityAction(named: "Delete") {}
      .accessibilityAdjustableAction { _ in }
      .render()
    let points = Text("Points")
      .accessibilityActivationPoint(.center)
      .accessibilityActivationPoint(CGPoint(x: 12, y: 24))
      .accessibilityDragPoint(.top, description: "Drag from top")
      .accessibilityDropPoint(.bottom, description: "Drop at bottom")
      .accessibilityRespondsToUserInteraction(false)
      .render()
    let rendered = actions + points

    #expect(rendered.contains("data-accessibility-action=\"default\""))
    #expect(rendered.contains("data-accessibility-action=\"Delete\""))
    #expect(rendered.contains("data-event-accessibilityaction="))
    #expect(rendered.contains("data-accessibility-adjustable=\"true\""))
    #expect(rendered.contains("data-event-accessibilityadjust="))
    #expect(rendered.contains("data-event-keydown="))
    #expect(rendered.contains("data-accessibility-activation-point=\"50% 50%\""))
    #expect(rendered.contains("data-accessibility-activation-point=\"12px 24px\""))
    #expect(rendered.contains("data-accessibility-drag-point=\"50% 0%\""))
    #expect(rendered.contains("data-accessibility-drag-description=\"Drag from top\""))
    #expect(rendered.contains("data-accessibility-drop-point=\"50% 100%\""))
    #expect(rendered.contains("data-accessibility-drop-description=\"Drop at bottom\""))
    #expect(rendered.contains("data-accessibility-responds-to-user-interaction=\"false\""))
  }

  @Test
  func accessibilityModifiersAttachToMutableElements() {
    let rendered = Button("Save") {}
      .accessibilityLabel("Save")
      .accessibilityHint("Stores the draft")
      .accessibilityAction(.default) {}
      .render()

    #expect(rendered.contains("<button"))
    #expect(rendered.contains("aria-label=\"Save\""))
    #expect(rendered.contains("aria-description=\"Stores the draft\""))
    #expect(rendered.contains("data-accessibility-action=\"default\""))
    #expect(!rendered.contains("swui-semantic-modifier\"><button"))
  }

  @Test
  func tapGestureHonorsRequiredClickCount() throws {
    let recorder = GestureRecorder()

    let artifact = Text("Tap")
      .onTapGesture(count: 2) {
        recorder.increment()
      }
      .renderArtifact()

    let click = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "click" })
    click.invoke()
    #expect(recorder.count == 0)

    click.invoke()
    #expect(recorder.count == 1)
  }

  @Test(.timeLimit(.minutes(1)))
  func longPressGestureWaitsForMinimumDuration() async throws {
    let recorder = GestureRecorder()
    let pressing = PressingRecorder()

    let artifact = Text("Hold")
      .onLongPressGesture(minimumDuration: 0.02, maximumDistance: 10, pressing: { isPressing in
        pressing.append(isPressing)
      }) {
        recorder.increment()
      }
      .renderArtifact()

    let pointerDown = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "pointerdown" })
    let pointerUp = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "pointerup" })

    pointerDown.invoke(with: DOMEvent(clientX: 0, clientY: 0))
    pointerUp.invoke(with: DOMEvent(clientX: 0, clientY: 0))
    try await Task.sleep(for: .milliseconds(40))
    #expect(recorder.count == 0)

    pointerDown.invoke(with: DOMEvent(clientX: 0, clientY: 0))
    try await Task.sleep(for: .milliseconds(40))
    #expect(recorder.count == 1)
    pointerUp.invoke(with: DOMEvent(clientX: 0, clientY: 0))
    #expect(pressing.values == [true, false, true, false])
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
    #expect(
      rendered.contains(
        "class=\"swui-picker-segmented swui-control-regular swui-material swui-material-bar\""))
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
  func rendersSegmentedPickerControlGeometryStyles() {
    @State var status = "published"

    let rendered = Picker("Status", selection: $status) {
      PickerOption("Draft", value: "draft")
      PickerOption("Published", value: "published")
    }
    .pickerStyle(.segmented)
    .environment(\.theme, .system)
    .render()

    #expect(rendered.contains(".swui-picker-segmented {"))
    #expect(rendered.contains("min-height: 0;"))
    #expect(rendered.contains("border-radius: var(--swui-button-radius);"))
    #expect(rendered.contains("padding: 2px;"))
    #expect(rendered.contains(".swui-picker-segmented .swui-picker-segment-label {"))
    #expect(rendered.contains("padding: 6px 14px;"))
    #expect(rendered.contains("border-radius: calc(var(--swui-button-radius) - 2px);"))
    #expect(rendered.contains("white-space: nowrap;"))
  }

  @Test
  func rendersMenu() {
    let rendered = Menu("Options") {
      Text("Edit")
      Text("Delete")
    }
    .render()

    #expect(rendered.contains("<details class=\"swui-menu\">"))
    #expect(
      rendered.contains(
        "class=\"swui-menu-label swui-glass swui-glass-interactive swui-material-regular\""))
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
    #expect(
      rendered.contains(
        "class=\"swui-tab-item swui-glass swui-glass-interactive swui-material-regular\""))
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

    #expect(rendered.contains("class=\"swui-searchable swui-search-placement-automatic swui-fill-h\""))
    #expect(rendered.contains("data-search-presented=\"true\""))
    #expect(rendered.contains("role=\"search\""))
    #expect(rendered.contains("class=\"swui-search-field swui-material swui-material-thin\""))
    #expect(rendered.contains("type=\"search\""))
    #expect(rendered.contains("placeholder=\"Search\""))
    #expect(rendered.contains("aria-label=\"Search\""))
  }

  @Test
  func rendersSearchablePlacementAndPresentationBinding() {
    @State var query = ""
    @State var isPresented = false

    let rendered = VStack {
      Text("Items")
    }
    .searchable(text: $query, isPresented: $isPresented, placement: .toolbar, prompt: "Filter")
    .render()

    #expect(rendered.contains("class=\"swui-searchable swui-search-placement-toolbar swui-fill-h\""))
    #expect(rendered.contains("data-search-presented=\"false\""))
    #expect(!rendered.contains("role=\"search\""))
    #expect(!rendered.contains("placeholder=\"Filter\""))
  }

  @Test
  func rendersSearchSuggestionsScopesAndCompletion() throws {
    @State var query = ""
    @State var scope = "all"
    @State var tokens = ["swift", "wasm"]

    let artifact = VStack {
      Text("Items")
    }
    .searchable(text: $query) {
      Text("Apple").searchCompletion("apple")
      Text("Banana").searchCompletion("banana")
    }
    .searchTokens($tokens) { token in
      Text(token)
    }
    .searchScopes($scope) {
      SearchScope("All", value: "all")
      SearchScope("Favorites", value: "favorites")
    }
    .renderArtifact()
    let rendered = artifact.html

    #expect(rendered.contains("class=\"swui-search-suggestions\" role=\"listbox\""))
    #expect(rendered.contains("data-search-completion=\"apple\""))
    #expect(rendered.contains("data-search-completion=\"banana\""))
    #expect(rendered.contains("class=\"swui-search-tokens\""))
    #expect(rendered.contains("class=\"swui-search-token\" type=\"button\" data-search-token=\"swift\""))
    #expect(rendered.contains("data-search-token=\"wasm\""))
    #expect(rendered.contains("class=\"swui-search-scopes\" role=\"radiogroup\""))
    #expect(rendered.contains("data-search-scope=\"all\""))
    #expect(rendered.contains("name=\"swui-search-scopes-"))
    #expect(rendered.contains("checked"))
    #expect(rendered.contains("data-search-scope=\"favorites\""))

    let scopeChange = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "change" })
    scopeChange.invoke(with: DOMEvent(value: "favorites"))
    #expect(scope == "favorites")

    let tokenClick = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "click" })
    tokenClick.invoke(with: DOMEvent())
    #expect(tokens == ["wasm"])
  }

  @Test
  func searchScopesUseDistinctNativeRadioGroups() {
    @State var firstScope = "all"
    @State var secondScope = "all"

    let rendered = VStack {
      Text("First")
        .searchScopes($firstScope) {
          SearchScope("All", value: "all")
          SearchScope("Favorites", value: "favorites")
        }
      Text("Second")
        .searchScopes($secondScope) {
          SearchScope("All", value: "all")
          SearchScope("Recent", value: "recent")
        }
    }
    .render()

    let names = searchScopeGroupNames(in: rendered)
    #expect(names.count == 4)
    #expect(Set(names).count == 2)
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
    #expect(
      rendered.contains(
        "<dialog class=\"swui-presentation swui-presentation-alert swui-material swui-material-thick\""
      ))
    #expect(rendered.contains("role=\"alertdialog\""))
    // The binding drives the SSR marker and the `open` attribute together.
    #expect(rendered.contains("data-presented=\"true\""))
    #expect(rendered.contains("open"))
    // Every presentation kind light-dismisses on an outside tap; for an
    // alert the backdrop tap is a safe cancel that runs no action.
    #expect(rendered.contains("closedby=\"any\""))
    // The close event syncs the binding back when the dialog is dismissed.
    #expect(rendered.contains("data-event-close="))
    #expect(rendered.contains("class=\"swui-presentation-surface\""))
    #expect(rendered.contains("<h2 class=\"swui-presentation-title\">Delete file?</h2>"))
    // The message wrapper is a flow container so it can legally hold block
    // content such as a Text (which itself lowers to <p>).
    #expect(
      rendered.contains(
        "<div class=\"swui-presentation-message\"><p class=\"swui-text\">This cannot be undone.</p></div>"
      ))
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
    #expect(
      rendered.contains(
        "<dialog class=\"swui-presentation swui-presentation-sheet swui-material swui-material-thick\""
      ))
    #expect(rendered.contains("role=\"dialog\""))
    #expect(rendered.contains("data-presented=\"false\""))
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

private enum FocusField: Hashable, Codable, Sendable {
  case title
}

private struct ColorSchemeShapeStyle: WebShapeStyle {
  func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
    ResolvedStyle(cssValue: context.colorScheme == .dark ? "#111111" : "#eeeeee")
  }
}

private struct ChangeRecord<Value: Equatable>: Equatable {
  var oldValue: Value
  var newValue: Value
}

private final class ChangeRecorder<Value: Equatable> {
  private(set) var records: [ChangeRecord<Value>] = []

  func record(oldValue: Value, newValue: Value) {
    records.append(ChangeRecord(oldValue: oldValue, newValue: newValue))
  }
}

private final class GestureRecorder: Sendable {
  private let storage = Mutex(0)

  var count: Int {
    storage.withLock { $0 }
  }

  func increment() {
    storage.withLock { $0 += 1 }
  }
}

private final class PressingRecorder: Sendable {
  private let storage = Mutex([Bool]())

  var values: [Bool] {
    storage.withLock { $0 }
  }

  func append(_ value: Bool) {
    storage.withLock { $0.append(value) }
  }
}

private func searchScopeGroupNames(in rendered: String) -> [String] {
  rendered.components(separatedBy: "name=\"").dropFirst().compactMap { part in
    guard let end = part.firstIndex(of: "\"") else {
      return nil
    }
    let name = String(part[..<end])
    return name.hasPrefix("swui-search-scopes-") ? name : nil
  }
}

private struct OnChangeProbe: ClientComponent {
  let value: Int
  let recorder: ChangeRecorder<Int>

  var body: some HTML {
    Text("Value")
      .onChange(of: value, initial: true) { oldValue, newValue in
        recorder.record(oldValue: oldValue, newValue: newValue)
      }
  }
}
