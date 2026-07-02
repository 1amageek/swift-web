import Foundation
import SwiftHTML
import SwiftWebUI

// Editorial content for the Content and Layout & organization categories.
// `typography` is the exemplar page for content-heavy components.

func contentLayoutDiscussion(for id: String) -> [String]? {
    switch id {
    case "typography":
        return [
            "Text displays a read-only string. Semantic fonts — largeTitle through caption — carry size, weight, and line height together, so a page keeps one typographic rhythm instead of ad-hoc pixel sizes.",
            "The web-specific as: selector chooses the HTML element the text renders into (p, span, h1–h6, code), keeping markup semantic and headings accessible while the visual style stays with .font(_:).",
        ]
    case "image":
        return [
            "Image(systemName:) renders an SF Symbol identifier as an inline SVG glyph. The web has no access to the SF Symbols font, so the framework ships approximating 24×24 vector glyphs for a curated identifier set; each glyph fills with currentColor, so it inherits the surrounding foreground exactly like a symbol in SwiftUI.",
            "Symbols size through .font(_:) rather than .frame, keeping icons proportional to neighbouring text. Identifiers outside the shipped set render the identifier as text — surfacing the name instead of failing silently — and Image(_:) remains the plain img path for URL-based assets.",
        ]
    case "colorvalue":
        return [
            "Color is the framework's single concrete color type: the standard palette (.red through .gray), semantic roles (.accent, .danger, and the surface tokens), and literals from hex, sRGB, or HSB components. A color paints the region it is given and composes in any ShapeStyle position — foregrounds, backgrounds, and tints.",
            "Every color resolves to a CSS value rather than a platform color: palette colors lower to light-dark() pairs that adapt per appearance, semantic roles resolve to root custom properties, and opacity(_:)/mix(with:by:) lower to color-mix(), so derived colors stay scheme-adaptive.",
        ]
    case "code":
        return [
            "Code renders source text as a pre block with an optional line-number gutter and a language hint. Reach for it for usage examples, configuration excerpts, and terminal output — anywhere the content is code rather than prose.",
            "Each line lowers to its own span with the number in an aria-hidden gutter, so selecting and copying grabs only the source. The language is emitted as data-language and folded into the block's accessible label, and startLine offsets the numbering for mid-file excerpts.",
        ]
    case "label":
        return [
            "Label pairs an icon with a title and treats the pair as one unit: one font, one foreground style, one gap. Reach for it in lists, menus, and settings rows where icon-plus-text is the row's identity rather than decoration.",
            "The icon is the same inline SVG glyph Image(systemName:) draws, so it inherits the text color and scales with the label's font; the icon-title gap is a style-system token, keeping rows aligned across a whole list.",
        ]
    case "groupbox":
        return [
            "GroupBox gathers related views onto one bordered surface with an optional title, giving a set of rows or summary content a visual boundary of its own. Use it when content forms a logical unit inside a larger page — a storage summary, grouped settings, an aside.",
            "The box lowers to a semantic section composing the regular material, so it frosts whatever sits behind it; a string title renders as a real heading above the content, and the label slot takes any view when text is not enough.",
        ]
    case "list":
        return [
            "List is a container of rows. Rows are declared explicitly with ListRow — each row can carry leading and trailing content, badges, and controls — and the list applies one of five presentation styles without touching the rows themselves.",
            "The container lowers to role=\"list\" markup and the style resolves through the environment, exactly like listStyle in SwiftUI: .plain and .inset stay flush with the content, .grouped and .insetGrouped draw the settings-style surface, and .sidebar tightens rows for navigation.",
        ]
    case "section":
        return [
            "Section groups rows inside a List or Form under an optional header and footer. The header names the group; the footer carries explanatory copy that belongs to the group rather than to any single row.",
            "The group lowers to a semantic section element and a string header renders as a real heading, so grouped settings keep a navigable document outline. Header and footer are builder slots when plain text is not enough.",
        ]
    case "disclosuregroup":
        return [
            "DisclosureGroup hides secondary content behind a disclosure control — advanced options, verbose details, anything that should not compete with the primary content until asked for.",
            "It lowers to a native details/summary pair, so expansion works before any client runtime loads. Without a binding the group starts collapsed and the browser owns the toggle; pass isExpanded: to drive the open state from Swift.",
        ]
    case "grid":
        return [
            "Grid lays out a small, fully-declared table of views: rows are GridRow children and the column count emerges from the widest row, so cells align across rows without measurement code. Use it for icon-and-caption arrangements and label/value pairs; reach for the lazy grids when content is long or data-driven.",
            "The container lowers to CSS Grid — horizontalSpacing and verticalSpacing become the column and row gaps in points, and alignment lowers onto the tracks — so the browser solves the layout.",
        ]
    case "lazy":
        return [
            "The lazy stacks and grids — LazyVStack, LazyHStack, LazyVGrid, LazyHGrid — arrange children like their eager counterparts but declare that children need not all be realized up front. Use them for long, data-driven runs of content, usually inside a ScrollView.",
            "On the web, laziness lowers to content-visibility: auto with a contained intrinsic size on every child: the whole run exists in the DOM, but the browser skips layout and paint for offscreen children until they scroll into view. Grid tracks come from [GridItem] — fixed, flexible, or adaptive.",
        ]
    case "tabview":
        return [
            "TabView pages between mutually exclusive Tab children, each identified by a string value; the selection binding's current value chooses the active tab. Tab items compose interactive glass, and the active panel renders below the bar.",
            "The bar and panels lower together: every Tab renders a hidden radio plus its role=\"tabpanel\" content, and CSS reveals the checked tab's panel — so switching works before any client runtime loads, while one delegated change handler keeps the Swift binding in sync.",
        ]
    case "stacks":
        return [
            "VStack and HStack arrange children along one axis with token spacing and a cross-axis alignment; ZStack overlays its children in a shared frame. They are the primitive composition tools every other layout builds on.",
            "The stacks lower to CSS flex columns and rows and ZStack lowers to a single-cell grid, so the browser is the layout engine — there is no Swift-side solver. HStack never wraps, matching SwiftUI: overflowing content overflows rather than dropping onto a second line.",
        ]
    case "spacer":
        return [
            "Spacer is a flexible, invisible region that expands along the enclosing stack's axis, pushing its siblings apart. Where it sits determines the layout: after content it pushes leading, before content it pushes trailing, and between two views it splits them to opposite edges.",
            "It lowers to a flex-grow element whose axis resolves from the parent stack — width in an HStack, height in a VStack — and multiple spacers share the leftover space equally. minLength keeps a floor when space runs out.",
        ]
    case "divider":
        return [
            "Divider draws a hairline rule that separates content. Its orientation is inferred from the enclosing stack — a horizontal rule between VStack children, a vertical rule between HStack children — so the same declaration works in both.",
            "The rule is a role=\"separator\" element whose color comes from the active style system's border token. Give it a frame to constrain its length, and give a vertical divider's row a height so the rule has something to span.",
        ]
    default:
        return nil
    }
}

func contentLayoutParity(for id: String) -> String? {
    switch id {
    case "typography":
        return "Same shape as SwiftUI's Text with .font/.fontWeight/.foregroundStyle; the as: element selector is the sanctioned web extension."
    case "image":
        return "Same shape as SwiftUI's Image(systemName:); on the web the symbol lowers to an inline SVG from a curated glyph set, and unknown identifiers fall back to readable text."
    case "colorvalue":
        return "Same shape as SwiftUI's Color — palette, semantic, and literal initializers with opacity(_:) and mix(with:by:) — resolving to CSS light-dark(), var(), and color-mix() values instead of platform colors."
    case "code":
        return "A web extension with no SwiftUI counterpart; it keeps the framework's declarative shape — Code(language:) { source } — and composes with the standard modifiers."
    case "label":
        return "Same shape as SwiftUI's Label(_:systemImage:); the icon renders from the web glyph set instead of the SF Symbols font."
    case "groupbox":
        return "Same shape as SwiftUI's GroupBox(_:content:), including the label-builder form; the surface composes the regular material."
    case "list":
        return "Same shape as SwiftUI's List with listStyle(_:); the explicit ListRow wrapper is the web extension — rows are declared rather than derived from content."
    case "section":
        return "Same shape as SwiftUI's Section(_:content:) with header and footer builders; a string header lowers to a real heading element."
    case "disclosuregroup":
        return "Same shape as SwiftUI's DisclosureGroup(_:content:) with the optional isExpanded binding; expansion is a native details/summary interaction on the web."
    case "grid":
        return "Same shape as SwiftUI's Grid and GridRow with alignment and spacing; the rows lower to CSS Grid tracks and gaps."
    case "lazy":
        return "Same shape as SwiftUI's lazy stacks and grids, including [GridItem] tracks; laziness lowers to the browser's content-visibility engine instead of view recycling."
    case "tabview":
        return "Same shape as SwiftUI's TabView(selection:) with Tab(_:systemImage:value:); the selection is a String on the web and tab switching degrades to a pure-CSS radio group."
    case "stacks":
        return "Same shape as SwiftUI's VStack, HStack, and ZStack with alignment and spacing parameters; the stacks lower to flexbox and a single-cell grid."
    case "spacer":
        return "Same shape as SwiftUI's Spacer(minLength:); it lowers to a flex-grow region and resolves its axis from the enclosing stack."
    case "divider":
        return "Same shape as SwiftUI's Divider(); orientation resolves from the enclosing stack and the hairline color comes from the style system."
    default:
        return nil
    }
}

func contentLayoutVariants(for id: String) -> [CatalogVariant]? {
    switch id {
    case "typography":
        return [
            CatalogVariant("Type ramp", detail: "The semantic fonts from .largeTitle to .caption.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Large Title").font(.largeTitle)
                    Text("Title").font(.title)
                    Text("Headline").font(.headline)
                    Text("Body").font(.body)
                    Text("Footnote").font(.footnote)
                    Text("Caption").font(.caption)
                }
            },
            CatalogVariant("Hierarchy", detail: ".foregroundStyle(.primary/.secondary) derives from the current foreground.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Primary label")
                    Text("Secondary label").foregroundStyle(.secondary)
                    Text("Accent label").foregroundStyle(.accent)
                }
            },
            CatalogVariant("Weights", detail: ".fontWeight(_:) from regular to bold.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Regular weight")
                    Text("Medium weight").fontWeight(.medium)
                    Text("Semibold weight").fontWeight(.semibold)
                    Text("Bold weight").fontWeight(.bold)
                }
            },
            CatalogVariant("Semantic elements", detail: "as: renders headings, code, and inline spans.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Section heading", as: .h3)
                    Text("let value = 42", as: .code)
                    Text("An inline span", as: .span).foregroundStyle(.secondary)
                }
            },
        ]
    case "image":
        return [
            CatalogVariant("Symbol set", detail: "A sample of the shipped glyph set; every glyph is a 24×24 inline SVG.") {
                HStack(spacing: .medium) {
                    Image(systemName: "star.fill").font(.title2)
                    Image(systemName: "heart.fill").font(.title2)
                    Image(systemName: "bell.badge").font(.title2)
                    Image(systemName: "envelope").font(.title2)
                    Image(systemName: "photo").font(.title2)
                    Image(systemName: "chart.bar").font(.title2)
                }
            },
            CatalogVariant("Sized by font", detail: ".font(_:) scales the glyph with the type ramp instead of a frame.") {
                HStack(spacing: .medium) {
                    Image(systemName: "star.fill").font(.body)
                    Image(systemName: "star.fill").font(.title2)
                    Image(systemName: "star.fill").font(.largeTitle)
                }
            },
            CatalogVariant("Inherits the foreground", detail: "The glyph fills with currentColor, taking the surrounding foreground style.") {
                VStack(alignment: .leading, spacing: .small) {
                    HStack(spacing: .xsmall) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Verified")
                    }
                    .foregroundStyle(.accent)
                    HStack(spacing: .xsmall) {
                        Image(systemName: "pin.fill")
                        Text("Pinned")
                    }
                    .foregroundStyle(.secondary)
                }
            },
            CatalogVariant("Unknown identifier", detail: "Identifiers outside the glyph set surface the name as text instead of rendering nothing.") {
                Image(systemName: "sparkles")
            },
        ]
    case "colorvalue":
        return [
            CatalogVariant("Standard palette", detail: "The system palette adapts between light and dark via light-dark().") {
                HStack(spacing: .xsmall) {
                    colorSwatch(.red)
                    colorSwatch(.orange)
                    colorSwatch(.yellow)
                    colorSwatch(.green)
                    colorSwatch(.blue)
                    colorSwatch(.indigo)
                    colorSwatch(.purple)
                    colorSwatch(.pink)
                }
            },
            CatalogVariant("Opacity", detail: ".opacity(_:) lowers to color-mix(), keeping the base color scheme-adaptive.") {
                HStack(spacing: .xsmall) {
                    colorSwatch(.blue)
                    colorSwatch(Color.blue.opacity(0.6))
                    colorSwatch(Color.blue.opacity(0.3))
                    colorSwatch(Color.blue.opacity(0.1))
                }
            },
            CatalogVariant("Semantic roles", detail: ".accent, .danger, and the surface tokens resolve to root custom properties.") {
                HStack(spacing: .xsmall) {
                    colorSwatch(.accent)
                    colorSwatch(.danger)
                    colorSwatch(.surfaceRaised)
                    colorSwatch(.border)
                }
            },
            CatalogVariant("Literals", detail: "Hex, sRGB, and HSB initializers lower to exact CSS values.") {
                HStack(spacing: .xsmall) {
                    colorSwatch(Color(hex: 0x5E5CE6))
                    colorSwatch(Color(red: 1.0, green: 0.42, blue: 0.42))
                    colorSwatch(Color(hue: 0.55, saturation: 0.65, brightness: 0.9))
                }
            },
        ]
    case "code":
        return [
            CatalogVariant("Line numbers", detail: "The default gutter numbers every line; copying selects only the source.") {
                Code(language: "swift") {
                    """
                    let symbols = ["star.fill", "heart.fill"]
                    print(symbols.count)
                    """
                }
            },
            CatalogVariant("Plain", detail: "showsLineNumbers: false drops the gutter for short commands.") {
                Code(language: "bash", showsLineNumbers: false) {
                    "swift build --swift-sdk wasm32-unknown-wasi"
                }
            },
            CatalogVariant("Excerpt", detail: "startLine numbers a mid-file excerpt without renumbering.") {
                Code(language: "swift", startLine: 41) {
                    """
                    func demoHTML() -> String {
                        renderDemo()
                    }
                    """
                }
            },
        ]
    case "label":
        return [
            CatalogVariant("Icon and title", detail: "Label(_:systemImage:) pairs a glyph with its text as one unit.") {
                VStack(alignment: .leading, spacing: .small) {
                    Label("Favorites", systemImage: "star.fill")
                    Label("Messages", systemImage: "envelope")
                    Label("Settings", systemImage: "gear")
                }
            },
            CatalogVariant("Sized by font", detail: "The icon scales with the label's font, staying proportional to the title.") {
                VStack(alignment: .leading, spacing: .small) {
                    Label("Verified", systemImage: "checkmark.seal.fill").font(.title3)
                    Label("Verified", systemImage: "checkmark.seal.fill")
                    Label("Verified", systemImage: "checkmark.seal.fill").font(.caption)
                }
            },
            CatalogVariant("Foreground styles", detail: "Icon and title take the same foreground style together.") {
                VStack(alignment: .leading, spacing: .small) {
                    Label("Pinned", systemImage: "pin.fill").foregroundStyle(.accent)
                    Label("Archived", systemImage: "doc.text").foregroundStyle(.secondary)
                }
            },
        ]
    case "groupbox":
        return [
            CatalogVariant("Titled", detail: "The string title renders as a heading above the grouped content.") {
                GroupBox("Storage") {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text("iCloud Drive")
                        Text("128 GB of 200 GB used").font(.caption).foregroundStyle(.secondary)
                    }
                }
            },
            CatalogVariant("Untitled", detail: "GroupBox { } draws the bordered surface without a heading.") {
                GroupBox {
                    HStack(spacing: .small) {
                        Image(systemName: "envelope").foregroundStyle(.secondary)
                        Text("3 unread messages")
                    }
                }
            },
            CatalogVariant("Custom label", detail: "The label slot takes any view, such as a Label with an icon.") {
                GroupBox {
                    Text("Signed in as ada@example.com").font(.caption).foregroundStyle(.secondary)
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
            },
        ]
    case "list":
        return [
            CatalogVariant(".plain", detail: "Rows flush with the content, no surrounding surface.") {
                List {
                    ListRow { Text("Wi-Fi").badge("On") }
                    ListRow { Text("Bluetooth"); Spacer(); Text("Off").foregroundStyle(.secondary) }
                }
                .listStyle(.plain)
            },
            CatalogVariant(".inset", detail: "Plain rows with a leading and trailing inset.") {
                List {
                    ListRow { Text("Wi-Fi").badge("On") }
                    ListRow { Text("Bluetooth"); Spacer(); Text("Off").foregroundStyle(.secondary) }
                }
                .listStyle(.inset)
            },
            CatalogVariant(".grouped", detail: "The settings-style surface behind the row group.") {
                List {
                    ListRow { Text("Wi-Fi").badge("On") }
                    ListRow { Text("Updates").badge(3) }
                }
                .listStyle(.grouped)
            },
            CatalogVariant(".insetGrouped", detail: "The grouped surface with rounded, inset edges.") {
                List {
                    ListRow { Text("Wi-Fi").badge("On") }
                    ListRow { Text("Updates").badge(3) }
                }
                .listStyle(.insetGrouped)
            },
            CatalogVariant(".sidebar", detail: "Tightened rows for navigation lists.") {
                List {
                    ListRow { Text("Inbox").badge(12) }
                    ListRow { Text("Drafts") }
                }
                .listStyle(.sidebar)
            },
        ]
    case "section":
        return [
            CatalogVariant("Header", detail: "The string header renders as a real heading above the rows.") {
                Section("Account") {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text("Profile")
                        Text("Security")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            CatalogVariant("Header and footer", detail: "The footer carries explanatory copy for the whole group.") {
                Section("Privacy", footer: "Face ID data never leaves this device.") {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text("Face ID")
                        Text("Location Services")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            CatalogVariant("Footer only", detail: "Header and footer are independent builder slots.") {
                Section {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text("iPhone")
                        Text("iPad")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } footer: {
                    Text("Devices signed in with your account.").foregroundStyle(.secondary)
                }
            },
        ]
    case "disclosuregroup":
        return [
            CatalogVariant("Title", detail: "The string label becomes the native summary; the group starts collapsed and expands on click.") {
                DisclosureGroup("Advanced options") {
                    Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
                }
            },
            CatalogVariant("Custom label", detail: "The label slot takes any view, such as a Label with an icon.") {
                DisclosureGroup {
                    Text("Per-channel notification settings.").foregroundStyle(.secondary)
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
            },
            CatalogVariant("Structured content", detail: "The content slot holds full layouts — here a column of member labels.") {
                DisclosureGroup("Team") {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Label("Ada Lovelace", systemImage: "person.crop.circle")
                        Label("Grace Hopper", systemImage: "person.crop.circle")
                    }
                }
            },
        ]
    case "grid":
        return [
            CatalogVariant("Icons over captions", detail: "Cells align into columns derived from the widest row.") {
                Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Image(systemName: "photo")
                        Image(systemName: "heart.fill")
                        Image(systemName: "star.fill")
                    }
                    GridRow {
                        Text("Photos").font(.caption)
                        Text("Favorites").font(.caption)
                        Text("Featured").font(.caption)
                    }
                }
            },
            CatalogVariant("Label and value", detail: "Two-column rows keep values aligned without measurement code.") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
                    GridRow {
                        Text("Name").foregroundStyle(.secondary)
                        Text("Ada Lovelace")
                    }
                    GridRow {
                        Text("Role").foregroundStyle(.secondary)
                        Text("Analyst")
                    }
                    GridRow {
                        Text("Team").foregroundStyle(.secondary)
                        Text("Engines")
                    }
                }
            },
            CatalogVariant("Spacing", detail: "horizontalSpacing and verticalSpacing set the column and row gaps in points.") {
                Grid(horizontalSpacing: 32, verticalSpacing: 4) {
                    GridRow {
                        Text("A1"); Text("B1"); Text("C1")
                    }
                    GridRow {
                        Text("A2"); Text("B2"); Text("C2")
                    }
                }
            },
        ]
    case "lazy":
        return [
            CatalogVariant("LazyVStack", detail: "A vertical run; offscreen children defer layout and paint via content-visibility.") {
                LazyVStack(alignment: .leading, spacing: .xsmall) {
                    Text("Ada Lovelace")
                    Text("Grace Hopper")
                    Text("Katherine Johnson")
                }
            },
            CatalogVariant("LazyHStack", detail: "The same contract along the horizontal axis.") {
                LazyHStack(spacing: .small) {
                    Text("Ada")
                    Text("Grace")
                    Text("Alan")
                    Text("Katherine")
                }
            },
            CatalogVariant("LazyVGrid · flexible", detail: "Three flexible GridItem tracks share the width equally.") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: .xsmall) {
                    lazyCell("01")
                    lazyCell("02")
                    lazyCell("03")
                    lazyCell("04")
                    lazyCell("05")
                    lazyCell("06")
                }
                .frame(width: 220)
            },
            CatalogVariant("LazyVGrid · adaptive", detail: "Adaptive tracks fit as many minimum-width columns as space allows.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: .xsmall) {
                    lazyCell("01")
                    lazyCell("02")
                    lazyCell("03")
                    lazyCell("04")
                    lazyCell("05")
                    lazyCell("06")
                    lazyCell("07")
                    lazyCell("08")
                }
                .frame(width: 220)
            },
        ]
    case "tabview":
        return [
            CatalogVariant("Icons and titles", detail: "Tab(_:systemImage:value:) adds a glyph to each glass tab item.") {
                TabView(selection: Binding(get: { "summary" }, set: { _ in })) {
                    Tab("Summary", systemImage: "doc.text", value: "summary") {
                        Text("Summary panel content.").foregroundStyle(.secondary)
                    }
                    Tab("Activity", systemImage: "chart.bar", value: "activity") {
                        Text("Activity panel content.").foregroundStyle(.secondary)
                    }
                    Tab("Settings", systemImage: "gear", value: "settings") {
                        Text("Settings panel content.").foregroundStyle(.secondary)
                    }
                }
            },
            CatalogVariant("Text-only tabs", detail: "Tab(_:value:) renders title-only items in the same glass bar.") {
                TabView(selection: Binding(get: { "overview" }, set: { _ in })) {
                    Tab("Overview", value: "overview") {
                        Text("Overview panel content.").foregroundStyle(.secondary)
                    }
                    Tab("Metrics", value: "metrics") {
                        Text("Metrics panel content.").foregroundStyle(.secondary)
                    }
                    Tab("History", value: "history") {
                        Text("History panel content.").foregroundStyle(.secondary)
                    }
                }
            },
            CatalogVariant("Initial selection", detail: "The binding's current value checks the matching tab at render time.") {
                TabView(selection: Binding(get: { "activity" }, set: { _ in })) {
                    Tab("Summary", systemImage: "doc.text", value: "summary") {
                        Text("Summary panel content.").foregroundStyle(.secondary)
                    }
                    Tab("Activity", systemImage: "chart.bar", value: "activity") {
                        Text("Activity panel content.").foregroundStyle(.secondary)
                    }
                }
            },
        ]
    case "stacks":
        return [
            CatalogVariant("VStack", detail: "Children stack vertically with token spacing.") {
                VStack(spacing: .small) {
                    Text("Top")
                    Text("Middle")
                    Text("Bottom")
                }
            },
            CatalogVariant("HStack", detail: "Children line up on one row and never wrap.") {
                HStack(spacing: .small) {
                    Text("Leading")
                    Text("Center")
                    Text("Trailing")
                }
            },
            CatalogVariant("ZStack", detail: "Children overlay in a single-cell grid, aligned by the stack's alignment.") {
                ZStack {
                    VStack {}
                        .frame(width: 112, height: 64)
                        .background(Color.blue.opacity(0.18), in: .rect(cornerRadius: 12))
                    Text("Overlay").font(.caption).fontWeight(.medium)
                }
            },
            CatalogVariant("Composition", detail: "Nesting stacks builds rows: an HStack pairing an icon with a VStack of text.") {
                HStack(spacing: .small) {
                    Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text("Ada Lovelace").fontWeight(.semibold)
                        Text("Analyst").font(.caption).foregroundStyle(.secondary)
                    }
                }
            },
        ]
    case "spacer":
        return [
            CatalogVariant("Between", detail: "A spacer between two views pushes them to opposite edges.") {
                HStack(spacing: .small) {
                    Button("Back") {}.buttonStyle(.bordered)
                    Spacer()
                    Button("Save") {}.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            },
            CatalogVariant("Leading spacer", detail: "A spacer before content pushes it to the trailing edge.") {
                HStack(spacing: .small) {
                    Spacer()
                    Text("42 items").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            },
            CatalogVariant("Distributed", detail: "Multiple spacers share the leftover space equally.") {
                HStack(spacing: .small) {
                    Text("A")
                    Spacer()
                    Text("B")
                    Spacer()
                    Text("C")
                }
                .frame(maxWidth: .infinity)
            },
            CatalogVariant("Vertical", detail: "In a VStack the same spacer expands vertically.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Header").fontWeight(.semibold)
                    Spacer()
                    Text("Footer").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, height: 96, alignment: .leading)
            },
        ]
    case "divider":
        return [
            CatalogVariant("Horizontal", detail: "Between VStack children the rule spans the width.") {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Section one")
                    Divider()
                    Text("Section two")
                }
                .frame(maxWidth: .infinity)
            },
            CatalogVariant("Vertical", detail: "Between HStack children the rule turns vertical; the row's height gives it a span.") {
                HStack(spacing: .medium) {
                    Text("Edit")
                    Divider()
                    Text("Share")
                    Divider()
                    Text("Delete")
                }
                .frame(height: 44)
            },
            CatalogVariant("Constrained", detail: "A frame limits the rule's length for a short separator.") {
                VStack(spacing: .small) {
                    Text("Centered heading")
                    Divider().frame(width: 120)
                    Text("Short rule").font(.caption).foregroundStyle(.secondary)
                }
            },
        ]
    default:
        return nil
    }
}

// MARK: - Shared variant helpers

/// A small rounded swatch that paints the given color, used by the Color page.
private func colorSwatch(_ color: Color) -> some HTML {
    VStack {}
        .frame(width: 24, height: 24)
        .background(color, in: .rect(cornerRadius: 6))
}

/// A compact numbered cell that makes lazy grid tracks visible.
private func lazyCell(_ label: String) -> some HTML {
    Text(label)
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(.all, 4)
        .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 6))
}
