# SwiftWebUI Core Design

SwiftWebUI should follow SwiftUI's interface shape without copying platform-specific implementation details. The core model is a layered graph:

```mermaid
flowchart TD
    A["User Component"] --> B["Component graph"]
    C["DynamicProperty wrappers"] --> B
    D["Modifier graph"] --> B
    E["Style abstraction"] --> D
    B --> F["SwiftHTML HTMLGraph"]
    F --> G["SSR HTML"]
    F --> H["Hydration manifest"]
    F --> I["DOM patches"]
```

## Ownership

| Layer | Owner | Responsibility |
|---|---|---|
| Component graph | `SwiftHTML` | Component identity, child traversal, state slot registration, environment reads, hydration boundaries, diagnostics |
| DynamicProperty | `SwiftHTML` | Runtime-backed property wrappers used during render, hydration, and client updates |
| Modifier graph | `SwiftHTML` core + `SwiftWebUI` modifiers | Ordered modifier composition and lowering to attributes, wrappers, environment scopes, handlers, or layout metadata |
| Style abstraction | `SwiftWebUI` | SwiftUI-like style values resolved through `EnvironmentValues`, `ColorScheme`, and `Theme` into web-safe CSS output |

`SwiftWebUI` must not introduce a second renderer. It produces components and modifiers that lower into the existing `SwiftHTML` graph.

## Component Graph

The component graph is the semantic tree produced by `Component.body`. It is not the final DOM tree. The final render artifact remains the arena-backed `HTMLGraph`.

```mermaid
flowchart LR
    A["Component value"] --> B["body"]
    B --> C["HTML / child components"]
    C --> D["HTMLGraphBuilder"]
    D --> E["HTMLGraph arenas"]
    D --> F["HydrationManifest"]
    D --> G["ClientHandlerManifest"]
    D --> H["Diagnostics"]
```

### Rules

| Rule | Design |
|---|---|
| `body` shape | `var body: some HTML { get }`; it is not a function |
| Identity | Component identity is derived from type, render path, and explicit keys |
| State lifetime | State is keyed by component identity plus property source location |
| Client boundary | `ClientComponent` owns state, event closures, and WASM hydration |
| Server boundary | `ServerComponent` may render inside a client boundary as a server slot |
| Diffing | Node fingerprints and keys drive graph diff; component identity drives state continuity |
| Output | Components lower to `HTMLGraph`; components do not render strings directly |

`HTMLNodeKind.component` is the hydration and diagnostic marker. It should not become a recursive public component tree.

## DynamicProperty

Dynamic properties are property wrappers whose value depends on the current render context. In SwiftWebUI this includes `@State`, `@Binding`, `@Environment`, and future UI runtime wrappers. Request-scoped server wrappers such as `@Session` belong to SwiftWeb page and action surfaces, not to the SwiftWebUI component core.

```mermaid
sequenceDiagram
    participant R as Renderer
    participant C as Component
    participant D as DynamicProperty
    participant G as HTMLGraphBuilder

    R->>G: enter component context
    G->>D: install task-local render context
    R->>C: evaluate body
    C->>D: read/write wrappedValue
    D->>G: register reads, slots, diagnostics
    G->>R: exit component context
```

### Proposed protocol

```swift
public protocol DynamicProperty {
    mutating func update()
}
```

`update()` is the public lifecycle hook. Internal storage still comes from task-local render contexts because Swift cannot generally enumerate property wrappers on a component without macro assistance.

### Wrapper responsibilities

| Wrapper | Responsibility |
|---|---|
| `@State` | Owns client-local mutable state for `ClientComponent`; registers a state slot |
| `@Binding` | Provides explicit read/write projection into state or observable models |
| `@Environment` | Reads `EnvironmentValues`; records visibility for hydration diagnostics |

### Context model

| Context field | Purpose |
|---|---|
| `componentID` | Stable owner of state slots and dirty marking |
| `componentType` | Diagnostic readability |
| `path` | Render-path identity and diagnostics |
| `environment` | Current scoped values |
| `stateStore` | State slot storage |
| `phase` | Server render, client hydrate, or client update |
| `visibility` | Server-owned or client-owned evaluation |

Reading a dynamic property outside an installed render context should use a local fallback only where SwiftUI also permits detached construction. Development builds should emit diagnostics for unsafe reads.

## Modifier Graph

Modifiers must be ordered nodes. They are not just accumulated attributes on concrete component structs. This matters because SwiftUI modifier order is semantic:

```swift
Text("Title")
    .padding()
    .backgroundStyle(.surface)
```

is not equivalent to:

```swift
Text("Title")
    .backgroundStyle(.surface)
    .padding()
```

### Proposed types

```swift
public protocol ComponentModifier: Sendable {
    associatedtype Body: HTML

    @HTMLBuilder
    func body(content: ModifierContent) -> Body
}

public struct ModifiedContent<Content: HTML, Modifier: ComponentModifier>: HTML {
    public let content: Content
    public let modifier: Modifier
}

public struct ModifierContent: HTML {
    let build: @Sendable (inout HTMLGraphBuilder) -> HTMLNodeID
}
```

### Modifier categories

| Category | Lowering |
|---|---|
| Attribute | Merge into the nearest single element root when safe |
| Style | Resolve style values and emit CSS declarations or classes |
| Layout | Emit wrapper nodes when layout changes content geometry |
| Environment | Scope `EnvironmentValues` while building children |
| Event | Register handler records and emit hydration attributes |
| Accessibility | Emit semantic attributes, ARIA, or native HTML equivalents |
| Navigation | Bind route/history metadata to links or navigation containers |

`WebUIAttributeComponent` can remain as a low-level optimization, but public SwiftWebUI modifiers should work on any `HTML`, not only components that manually store `[HTMLAttribute]`.

## Style Abstraction

The detailed public style contract is defined in
[`SwiftWebUIStyleDesign.md`](SwiftWebUIStyleDesign.md). This section describes
the core primitives that support that contract.

SwiftUI has moved from color-specific APIs toward `ShapeStyle`. SwiftWebUI should do the same. `foregroundColor` should not be a new public API; `foregroundStyle` is the primary API.

```mermaid
flowchart LR
    A["foregroundStyle(.primary)"] --> B["WebShapeStyle"]
    B --> C["StyleResolver"]
    C --> D["EnvironmentValues"]
    D --> E["ColorScheme"]
    D --> F["Theme"]
    C --> G["ResolvedStyle"]
    G --> H["CSS declarations / classes"]
```

### Proposed protocols

```swift
public protocol WebShapeStyle: Sendable {
    func resolve(in context: StyleResolutionContext) -> ResolvedStyle
}

public struct StyleResolutionContext: Sendable {
    public let theme: Theme
    public let colorScheme: ColorScheme
    public let layoutDirection: LayoutDirection
    public let controlState: ControlState
}

public struct ResolvedStyle: Sendable, Equatable {
    public var cssValue: String
    public var style: Style
    public var classNames: [String]
}
```

### Public API direction

| API | Notes |
|---|---|
| `.foregroundStyle(_:)` | Text/icon foreground style |
| `.backgroundStyle(_:)` | Background style |
| `.tint(_:)` | Accent style for controls |
| `.border(_:width:)` | Shape-style border |
| `.shadow(...)` | Effect style |
| `.font(_:)` | Typography abstraction, not raw CSS string |
| `.controlSize(_:)` | Environment-backed control sizing |
| `.buttonStyle(_:)` | Semantic button treatment selection resolved by the active stylesheet |
| `.textFieldStyle(_:)` | Future semantic field treatment selection resolved by the active stylesheet |

Direct CSS is not a SwiftWebUI API. When SwiftWebUI needs concrete visual
output, it must use semantic classes, typed utilities, or typed `Style`
declarations that SwiftWebStyle validates and atomizes during render. The
styling goal state and raw-CSS ban are defined in
[`UtilityStylingGoalState.md`](UtilityStylingGoalState.md).

## Environment, ColorScheme, And Theme

ColorScheme is an environment value. `.preferredColorScheme(_:)` follows
SwiftUI's presentation semantics: the preference applies to the whole rendered
document no matter where in the tree it is declared, and the last writer during
a render wins. The page response encoder stamps the recorded scheme onto the
document root. Scoping a *subtree* to a scheme is the separate, SwiftUI-shaped
environment write:

```swift
content.environment(\.colorScheme, .dark)
```

The document style bootstrap is automatic. Whenever a render uses any
SwiftWebUI component or style modifier, the response encoder registers the root
stylesheet and runtime scripts and applies the root attributes
(`class="swui-root"`, `data-theme`, and the recorded
`data-color-scheme`) to the document `<body>`. Pages are styled without calling
any modifier; `.preferredColorScheme(_:)` only chooses the scheme. Passing
`nil` explicitly records "follow the user agent preference".

Theme is an environment value for component-level resolution. The
document stylesheet uses the process-installed theme:

```swift
let style = Theme(id: "brand") {
    .surface {
        .containerRadius(18)
        .containerShadow(.none)
    }
    .button {
        .radius(999)
    }
}

// Before serving the first page; the first installation wins.
SwiftWebUIDocumentStyle.install(theme: style)
```

There should be no separate color-scheme provider or context modifier beyond
these two surfaces. Environment remains the propagation mechanism for values
used by both server rendering and client hydration.

| Value | Responsibility | Defaulting model |
|---|---|---|
| `ColorScheme` | Light/dark color resolution for Swift-side style values | `\.colorScheme` defaults to `.light`; a document without a recorded preference lets CSS follow the user agent preference |
| `Theme` | Component-wide shape, spacing, material, control, and motion values | Document theme installs once per process (default `.liquidGlass`); third-party styles override only changed token groups |

`ColorScheme` and `Theme` are intentionally separate. Dark and light mode change color roles. Theme changes component language, such as Material-like controls or glass-like surfaces. A custom Theme must be built by overriding `Theme.default`, so every component keeps a defined fallback token.

```mermaid
flowchart LR
    A["ColorScheme"] --> B["color role CSS variables"]
    C["Theme"] --> D["component CSS variables"]
    B --> E["RootStylesheet"]
    D --> E
    E --> F["SwiftWebUI component classes"]
```

`.preferredColorScheme(_:)` does not create a root element and is not order
sensitive: it records the document preference and applies `\.colorScheme` to
its own subtree so Swift-side reads below it agree with the document.

| Visibility | Use |
|---|---|
| `serverOnly` | Database handles, services, request-only values |
| `client` | Codable values that can enter hydration snapshots |
| `runtimeOnly` | Values supplied separately by browser runtime |

## Implementation Direction

1. Add `DynamicProperty` as the shared lifecycle marker in `SwiftHTML`.
2. Make `State`, `Environment`, and `Bindable` conform to it.
3. Introduce `ModifiedContent`, `ModifierContent`, and `ComponentModifier`.
4. Move public SwiftWebUI modifiers from attribute-only mutation toward modifier wrappers.
5. Add `WebShapeStyle`, `ResolvedStyle`, and `StyleResolutionContext`.
6. Replace public `foregroundColor` with `foregroundStyle`.
7. Keep SwiftHTML typed style structures available as transport, while SwiftWebUI routes styling through SwiftWebStyle rather than raw CSS paths.
8. Keep `Theme.default` complete and make presets or third-party styles override that default through the builder DSL.

## Current Implementation

| Area | Implemented |
|---|---|
| Modifier graph | `ComponentModifier`, `ModifierContent`, and `ModifiedContent` live in `SwiftHTML`. |
| Style abstraction | `WebShapeStyle`, `SemanticShapeStyle`, `CSSShapeStyle`, `ResolvedStyle`, and style modifiers live in `SwiftWebUI`. |
| Style modifiers | `foregroundStyle`, `backgroundStyle`, `tint`, and `border` are available on all `HTML`. |
| Stylesheet output | SwiftHTML owns `Style`, generated standard CSS property helpers, `Stylesheet`, `CSSRule`, and `@StylesheetBuilder`; SwiftWebUI uses them for typed root CSS. |
| Theme | `Theme`, built-in presets, environment propagation, and builder-based overrides live in `SwiftWebUI`. |
| Control environment | `isEnabled`, `controlSize`, `controlState`, `tint`, `buttonStyle`, and `pickerStyle` are environment values. |
| Control styles | `ButtonStyleKind` and `PickerStyleKind` select semantic treatments whose CSS lives in `RootStylesheet`. |
| Binding-first controls | `TextField`, `Toggle`, `Slider`, `Stepper`, and `Picker` accept `Binding` values. |
| Typography | `Font`, `FontWeight`, and `FontDesign` provide SwiftUI-style text modifiers. |
| Navigation | `NavigationStack`, `NavigationLink`, `NavigationPath`, and `navigationTitle` are graph-level hooks. |
| Accessibility | Common accessibility modifiers map to semantic/ARIA attributes. |
| Page layout | `GridSystem` and `Pane` own responsive inline inset, columns, gutters, pane spans, and page vertical rhythm; `.frame(maxWidth:)` owns outer width constraints. |

This keeps SwiftHTML responsible for rendering correctness and keeps SwiftWebUI responsible for developer-facing UI ergonomics.
