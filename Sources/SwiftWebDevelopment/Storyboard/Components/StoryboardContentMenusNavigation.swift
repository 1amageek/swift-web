import Foundation
import SwiftHTML
import SwiftWebUI

// Editorial content for the Menus & actions and Navigation & search categories.
// `button-styles` is the exemplar page: its depth defines the quality bar for
// every other page in the catalog.

func menusNavigationDiscussion(for id: String) -> [String]? {
    switch id {
    case "button-styles":
        return [
            "A button style selects the visual recipe — fill, rim, and refraction — without touching the button's action or label. Styles resolve through the active style system, so the same declaration renders Liquid Glass under the default system and flatter chrome under a custom one.",
            "Reach for .glass on chrome that floats above content, .borderedProminent for the one primary action in a view, .bordered for secondary actions, and .plain when the button should read as text. Prominence is part of the style, not a separate axis.",
        ]
    case "button":
        return [
            "Button runs an action when the user activates it. On the web the action can be a client closure running in WASM, or a server action posted over HTTP — the call site looks the same either way.",
        ]
    case "control-sizes":
        return [
            "controlSize(_:) sets one environment value that every control in the subtree reads. The recipe scales padding, minimum height, and type together, so a denser or more prominent rendition never needs per-control adjustments — size the container and every button, menu, and field inside follows.",
            "Five sizes run from .mini to .extraLarge. Reach for .mini and .small in dense chrome such as toolbars and inspectors, keep .regular for general content, and use .large or .extraLarge when a single control anchors the view.",
        ]
    case "button-states":
        return [
            "tint(_:) swaps the accent an enabled control resolves without touching the global color scheme. The tint is an environment value, so recoloring a container recolors every control inside; semantic colors such as .danger resolve per appearance while palette colors stay fixed.",
            "disabled(_:) writes isEnabled into the same environment with AND semantics — a descendant .disabled(false) cannot re-enable a subtree an ancestor disabled. A disabled button renders the native disabled attribute alongside the recipe's dimmed state, so interaction stops in the browser, not in script.",
        ]
    case "links":
        return [
            "Link navigates to a URL. It lowers to a semantic <a href>, so the browser owns the behavior — open in a new tab, copy the address, follow a mailto: scheme — none of which a scripted button offers. On its own it reads as accent-colored text.",
            "Link resolves the same style environment as Button, so buttonStyle(_:), tint(_:), and controlSize(_:) dress the anchor as chrome without losing its semantics. Disabling a link removes the href and pointer events and marks it aria-disabled, because HTML has no disabled state for anchors.",
        ]
    case "menu":
        return [
            "Menu presents a list of actions behind one label. It lowers to a native <details>/<summary> pair, so the pulldown opens and closes without any client runtime; the label composes interactive glass and the floating panel composes the regular material, matching the other overlay chrome.",
            "The panel content is ordinary views — buttons, links, dividers — not a dedicated item type. There is deliberately no role=\"menu\": that ARIA role requires menuitem children, and a native disclosure of free content is the honest semantic.",
        ]
    case "toolbar":
        return [
            "toolbar(content:) attaches a command bar to the view it modifies. Each ToolbarItem declares a placement, and placements lower into four bar regions on the web — leading, principal, trailing, and the bottom bar — so declaration order inside the builder never constrains the visual layout. Empty bars and regions collapse.",
            "The bar is UI-layer chrome: it lays out above the content (below it for .bottomBar and .status) and composes the bar material, one step more frosted than a content container. Placements with no browser meaning, such as .keyboard, are intentionally absent so their use fails at compile time instead of silently doing nothing.",
        ]
    case "navigationstack":
        return [
            "NavigationStack is the single-column navigation container. It renders its root as a semantic <nav> marked data-navigation-stack, and the NavigationLink rows inside are real anchors the runtime can enhance into same-origin transitions.",
            "The path form is URL-backed: NavigationPath is the ordered list of URL path segments below the stack's base route. Pushing a value is a same-origin document transition — history is pushed, back and forward replay documents, and the page re-derives its path from the URL — never a separate client-side view stack. navigationDestination(for:destination:) renders the pushed leaf when the top segment converts to the destination's value type.",
        ]
    case "navigationlink":
        return [
            "NavigationLink points at another location in the app. It lowers to a semantic anchor marked data-navigation-link; the WASM host intercepts eligible same-origin anchors and performs an enhanced document transition — fetching the SSR document, merging, and pushing history — with native navigation as the fallback.",
            "On its own it renders as a navigation row. Like Link it resolves the button-style environment, so it can be dressed as chrome, and disabling it removes the href rather than leaving a clickable anchor that goes nowhere.",
        ]
    case "searchable":
        return [
            "searchable(text:prompt:) marks its content as searchable and attaches a search field above it. The field lowers to a role=\"search\" region holding a native <input type=\"search\"> bound to the query text — typing writes the binding on every input event — and composes the thin material so its fill tracks the active style system.",
            "The prompt doubles as the placeholder and the field's accessible label. Related modifiers layer onto the same field: searchSuggestions offers completions, searchScopes narrows the query with a radio row, and searchTokens renders removable filter chips.",
        ]
    default:
        return nil
    }
}

func menusNavigationParity(for id: String) -> String? {
    switch id {
    case "button-styles":
        return "Same shape as SwiftUI's buttonStyle(_:): the style is environment-driven and applies to every button in the subtree."
    case "button":
        return "Same shape as SwiftUI's Button(_:action:). The web adds server-action overloads that lower to form posts."
    case "control-sizes":
        return "Same shape as SwiftUI's controlSize(_:): one environment value with the same five sizes, read by every control in the subtree."
    case "button-states":
        return "Same shape as SwiftUI's tint(_:) and disabled(_:), including the AND composition — an ancestor's disabled cannot be undone below."
    case "links":
        return "Same shape as SwiftUI's Link(_:destination:): a label and a destination URL the browser opens, rather than an action to run."
    case "menu":
        return "Same shape as SwiftUI's Menu(_:content:); the disclosure is a native <details> element instead of a tracked popover."
    case "toolbar":
        return "Same shape as SwiftUI's toolbar(content:) with ToolbarItem and ToolbarItemGroup; placements lower into the four web bar regions."
    case "navigationstack":
        return "Same shape as SwiftUI's NavigationStack(path:root:), except the path is URL-backed — each NavigationPath component is a URL segment below the stack's base route, so a push is a same-origin document transition."
    case "navigationlink":
        return "Same shape as SwiftUI's NavigationLink(_:destination:), with a URL destination: activation navigates the document instead of pushing an in-memory view."
    case "searchable":
        return "Same shape as SwiftUI's searchable(text:prompt:): the field attaches to the modified view and edits the bound query text."
    default:
        return nil
    }
}

// `.searchable` requires a `Binding`; the variants gallery is static, so the
// demos bind a fixed query. The rendered field is the real component — only
// the write-back has nowhere to land in a static card.
private func staticSearchQuery(_ value: String = "") -> Binding<String> {
    Binding(get: { value }, set: { _ in })
}

func menusNavigationVariants(for id: String) -> [CatalogVariant]? {
    switch id {
    case "button-styles":
        return [
            CatalogVariant(".glass", detail: "Refracts the scene behind it; the default chrome style.") {
                Button("Continue") {}.buttonStyle(.glass)
            },
            CatalogVariant(".glassProminent", detail: "Glass with the accent fill for the primary action.") {
                Button("Continue") {}.buttonStyle(.glassProminent)
            },
            CatalogVariant(".borderedProminent", detail: "Solid accent fill; one per view.") {
                Button("Continue") {}.buttonStyle(.borderedProminent)
            },
            CatalogVariant(".bordered", detail: "Neutral fill for secondary actions.") {
                Button("Continue") {}.buttonStyle(.bordered)
            },
            CatalogVariant(".plain", detail: "Reads as text until hovered.") {
                Button("Continue") {}.buttonStyle(.plain)
            },
            CatalogVariant("Control sizes", detail: ".controlSize from .mini to .large scales padding and type together.") {
                HStack(spacing: .small) {
                    Button("Mini") {}.buttonStyle(.bordered).controlSize(.mini)
                    Button("Small") {}.buttonStyle(.bordered).controlSize(.small)
                    Button("Regular") {}.buttonStyle(.bordered)
                    Button("Large") {}.buttonStyle(.bordered).controlSize(.large)
                }
            },
            CatalogVariant("Tinted", detail: ".tint(_:) recolors the accent without changing the scheme.") {
                HStack(spacing: .small) {
                    Button("Save") {}.buttonStyle(.borderedProminent).tint(.green)
                    Button("Delete") {}.buttonStyle(.borderedProminent).tint(.danger)
                }
            },
            CatalogVariant("Disabled", detail: ".disabled(true) dims the recipe and blocks interaction.") {
                HStack(spacing: .small) {
                    Button("Enabled") {}.buttonStyle(.borderedProminent)
                    Button("Disabled") {}.buttonStyle(.borderedProminent).disabled(true)
                }
            },
        ]
    case "button":
        return [
            CatalogVariant("Default", detail: "Without a style the button resolves the neutral bordered recipe.") {
                Button("Continue") {}
            },
            CatalogVariant("Primary and secondary", detail: "One prominent action per view; companions stay bordered.") {
                HStack(spacing: .small) {
                    Button("Cancel") {}.buttonStyle(.bordered)
                    Button("Save") {}.buttonStyle(.borderedProminent)
                }
            },
            CatalogVariant("Label with icon", detail: "Any view can be the label; Label pairs an icon with the title.") {
                Button(action: {}) {
                    Label("Favorites", systemImage: "star.fill")
                }
                .buttonStyle(.bordered)
            },
            CatalogVariant("Icon only", detail: ".labelStyle(.iconOnly) hides the title visually but keeps it as the accessible name.") {
                Button(action: {}) {
                    Label("Favorite", systemImage: "heart.fill").labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
            },
            CatalogVariant("Fill width", detail: ".frame(maxWidth: .infinity) stretches the control to its container.") {
                Button("Continue") {}
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            },
        ]
    case "control-sizes":
        return [
            CatalogVariant(".mini", detail: "The densest rendition, for tightly packed chrome.") {
                Button("Mini") {}.buttonStyle(.bordered).controlSize(.mini)
            },
            CatalogVariant(".small", detail: "Compact controls for toolbars and inspectors.") {
                Button("Small") {}.buttonStyle(.bordered).controlSize(.small)
            },
            CatalogVariant(".regular", detail: "The default size; no modifier needed.") {
                Button("Regular") {}.buttonStyle(.bordered)
            },
            CatalogVariant(".large", detail: "A comfortable target for primary flows.") {
                Button("Large") {}.buttonStyle(.bordered).controlSize(.large)
            },
            CatalogVariant(".extraLarge", detail: "The largest rendition, for a control that anchors the view.") {
                Button("Extra large") {}.buttonStyle(.bordered).controlSize(.extraLarge)
            },
            CatalogVariant("Set on the container", detail: "One modifier on the stack sizes every control inside.") {
                HStack(spacing: .small) {
                    Button("Back") {}.buttonStyle(.bordered)
                    Button("Save") {}.buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
            },
        ]
    case "button-states":
        return [
            CatalogVariant("Accent (default)", detail: "Untinted controls resolve the theme accent.") {
                Button("Continue") {}.buttonStyle(.borderedProminent)
            },
            CatalogVariant(".tint(.green)", detail: "A palette tint recolors just this control.") {
                Button("Accept") {}.buttonStyle(.borderedProminent).tint(.green)
            },
            CatalogVariant(".tint(.danger)", detail: "The semantic danger tint resolves per appearance.") {
                Button("Delete") {}.buttonStyle(.borderedProminent).tint(.danger)
            },
            CatalogVariant("Tint on the container", detail: "Tint is an environment value: the stack recolors both controls.") {
                HStack(spacing: .small) {
                    Button("Follow") {}.buttonStyle(.borderedProminent)
                    Button("Share") {}.buttonStyle(.bordered)
                }
                .tint(.purple)
            },
            CatalogVariant("Disabled", detail: ".disabled(true) dims the recipe and renders the native disabled attribute.") {
                HStack(spacing: .small) {
                    Button("Enabled") {}.buttonStyle(.borderedProminent)
                    Button("Disabled") {}.buttonStyle(.borderedProminent).disabled(true)
                }
            },
            CatalogVariant("Disabled wins over tint", detail: "A disabled control dims its tinted recipe; the tint returns when re-enabled.") {
                Button("Accept") {}.buttonStyle(.borderedProminent).tint(.green).disabled(true)
            },
        ]
    case "links":
        return [
            CatalogVariant("Default", detail: "A bare Link renders as an accent-colored anchor.") {
                Link("Swift.org", destination: URL(string: "https://swift.org")!)
            },
            CatalogVariant("As a button", detail: ".buttonStyle(_:) dresses the anchor as chrome; it is still an <a href>.") {
                Link("Documentation", destination: URL(string: "https://developer.apple.com/documentation")!)
                    .buttonStyle(.bordered)
            },
            CatalogVariant("Call to action", detail: ".glassProminent gives the link the weight of a primary action.") {
                Link("Get started", destination: URL(string: "https://www.swift.org/getting-started/")!)
                    .buttonStyle(.glassProminent)
            },
            CatalogVariant("Tinted", detail: ".tint(_:) recolors the restyled anchor like any control.") {
                Link("Download", destination: URL(string: "https://www.swift.org/install/")!)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            },
            CatalogVariant("Label with icon", detail: "Any label view works; URL schemes such as mailto: come free with the anchor.") {
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    Label("Contact us", systemImage: "envelope")
                }
                .buttonStyle(.bordered)
            },
            CatalogVariant("Disabled", detail: "Disabling removes the href and pointer events and sets aria-disabled.") {
                Link("Unavailable", destination: URL(string: "https://swift.org")!)
                    .buttonStyle(.bordered)
                    .disabled(true)
            },
        ]
    case "menu":
        return [
            CatalogVariant("Default", detail: "The glass label discloses the action panel; no client runtime is involved.") {
                Menu("Options") {
                    Button("Duplicate") {}
                    Button("Move") {}
                    Button("Delete") {}
                }
            },
            CatalogVariant("Label with icon", detail: "The label slot takes any view, such as a Label.") {
                Menu {
                    Button("Profile") {}
                    Button("Sign out") {}
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
            },
            CatalogVariant("Grouped actions", detail: "Divider separates groups; a tint marks the destructive row.") {
                Menu("Edit") {
                    Button("Cut") {}
                    Button("Copy") {}
                    Button("Paste") {}
                    Divider()
                    Button("Delete") {}.tint(.danger)
                }
            },
            CatalogVariant("In a toolbar", detail: "The glass label sits naturally in bar chrome.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem {
                            Menu("More") {
                                Button("Rename") {}
                                Button("Archive") {}
                            }
                        }
                    }
            },
        ]
    case "toolbar":
        return [
            CatalogVariant("Four regions", detail: "Placements route items into the leading, principal, trailing, and bottom regions.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button("Back") {}.buttonStyle(.bordered).controlSize(.small)
                        }
                        ToolbarItem(placement: .principal) {
                            Text("Report")
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("Save") {}.buttonStyle(.borderedProminent).controlSize(.small)
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Text("3 of 12 selected").foregroundStyle(.secondary)
                        }
                    }
            },
            CatalogVariant("Primary action", detail: ".automatic and .primaryAction land in the trailing region.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem {
                            Button("Share") {}.buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
            },
            CatalogVariant("Principal title", detail: ".principal centers its item between the side regions.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Inbox")
                        }
                    }
            },
            CatalogVariant("ToolbarItemGroup", detail: "A group shares one placement and keeps its controls together.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button("Edit") {}.buttonStyle(.bordered).controlSize(.small)
                            Button("Share") {}.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
            },
            CatalogVariant("Bottom bar", detail: ".bottomBar and .status render a bar below the content.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Text("Updated just now").foregroundStyle(.secondary)
                        }
                    }
            },
        ]
    case "navigationstack":
        return [
            CatalogVariant("Root links", detail: "The stack renders a semantic <nav>; each row is a real anchor.") {
                NavigationStack {
                    VStack(alignment: .leading, spacing: .small) {
                        NavigationLink("Typography", destination: URL(string: "/storyboard/typography")!)
                        NavigationLink("Buttons", destination: URL(string: "/storyboard/button")!)
                        NavigationLink("Toolbar", destination: URL(string: "/storyboard/toolbar")!)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            CatalogVariant("Rows with icons", detail: "NavigationLink takes any label, such as a Label with an icon.") {
                NavigationStack {
                    VStack(alignment: .leading, spacing: .small) {
                        NavigationLink(destination: URL(string: "/storyboard/image")!) {
                            Label("Image", systemImage: "photo")
                        }
                        NavigationLink(destination: URL(string: "/storyboard/gauge")!) {
                            Label("Gauge", systemImage: "chart.bar")
                        }
                        NavigationLink(destination: URL(string: "/storyboard/code")!) {
                            Label("Code", systemImage: "doc.text")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            CatalogVariant("Navigation title", detail: ".navigationTitle(_:) attaches metadata the runtime lifts into the document title.") {
                NavigationStack {
                    VStack(alignment: .leading, spacing: .small) {
                        NavigationLink("Overview", destination: URL(string: "/storyboard/typography")!)
                        NavigationLink("Components", destination: URL(string: "/storyboard/button")!)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Library")
            },
        ]
    case "navigationlink":
        return [
            CatalogVariant("Default", detail: "A navigation row: a semantic anchor marked data-navigation-link.") {
                NavigationLink("Button styles", destination: URL(string: "/storyboard/button-styles")!)
            },
            CatalogVariant("Label with icon", detail: "Any view can be the label; Label pairs an icon with the title.") {
                NavigationLink(destination: URL(string: "/storyboard/image")!) {
                    Label("Image", systemImage: "photo")
                }
            },
            CatalogVariant("As a button", detail: ".buttonStyle(_:) dresses the anchor as chrome without changing its semantics.") {
                NavigationLink("Open toolbar", destination: URL(string: "/storyboard/toolbar")!)
                    .buttonStyle(.bordered)
            },
            CatalogVariant("Stacked rows", detail: "Rows compose into a link list inside any stack.") {
                VStack(alignment: .leading, spacing: .small) {
                    NavigationLink("Text", destination: URL(string: "/storyboard/typography")!)
                    NavigationLink("List", destination: URL(string: "/storyboard/list")!)
                    NavigationLink("Badge", destination: URL(string: "/storyboard/badge")!)
                }
            },
            CatalogVariant("Disabled", detail: "Disabling removes the href; the anchor cannot be followed or focused.") {
                NavigationLink("Unavailable", destination: URL(string: "/storyboard/typography")!)
                    .buttonStyle(.bordered)
                    .disabled(true)
            },
        ]
    case "searchable":
        return [
            CatalogVariant("Default", detail: "The field attaches above the content it searches; the prompt defaults to Search.") {
                List {
                    Text("Inbox")
                    Text("Archive")
                }
                .searchable(text: staticSearchQuery())
            },
            CatalogVariant("Custom prompt", detail: "The prompt is the placeholder and the field's accessible label.") {
                List {
                    Text("Design")
                    Text("Engineering")
                }
                .searchable(text: staticSearchQuery(), prompt: "Search teams")
            },
            CatalogVariant("Bound query", detail: "The field renders the bound text; typing writes it back on every input event.") {
                List {
                    Text("Inbox")
                }
                .searchable(text: staticSearchQuery("inbox"), prompt: "Search folders")
            },
        ]
    default:
        return nil
    }
}
