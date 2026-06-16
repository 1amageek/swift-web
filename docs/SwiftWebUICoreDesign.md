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
| Style abstraction | `SwiftWebUI` | SwiftUI-like style values resolved through `EnvironmentValues`, `Theme`, and `DesignStyle` into web-safe CSS output |

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

Dynamic properties are property wrappers whose value depends on the current render context. `@State`, `@Binding`, `@Environment`, `@Bindable`, and future runtime wrappers should share one lifecycle.

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
| `@Binding` | Provides read/write projection into state or observable models |
| `@Environment` | Reads `EnvironmentValues`; records visibility for hydration diagnostics |
| `@Bindable` | Projects bindings from `@Observable` reference models |
| `@Server` | Reads server-only capabilities; emits diagnostics if read inside client-owned render |

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
public protocol ComponentModifier {
    associatedtype Body: HTML

    @HTMLBuilder
    func body(content: ModifierContent) -> Body
}

public struct ModifiedContent<Content: HTML, Modifier: ComponentModifier>: HTML {
    public let content: Content
    public let modifier: Modifier
}

public struct ModifierContent: HTML {
    let build: (inout HTMLGraphBuilder) -> HTMLNodeID
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

SwiftUI has moved from color-specific APIs toward `ShapeStyle`. SwiftWebUI should do the same. `foregroundColor` should not be a new public API; `foregroundStyle` is the primary API.

```mermaid
flowchart LR
    A["foregroundStyle(.primary)"] --> B["WebShapeStyle"]
    B --> C["StyleResolver"]
    C --> D["EnvironmentValues"]
    D --> E["Theme"]
    D --> F["DesignStyle"]
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
    public let designStyle: DesignStyle
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
| `.buttonStyle(_:)` | Style protocol for button rendering |
| `.textFieldStyle(_:)` | Style protocol for text field rendering |

Raw CSS strings should remain as escape hatches, not the primary API. When SwiftWebUI needs to emit concrete CSS properties, it should use SwiftHTML `Style` helpers so standard CSS property names remain autocompleteable and shared across inline styles and stylesheet rules.

## Environment, Theme, And DesignStyle

Theme is an environment value:

```swift
content.environment(\.theme, .system)
```

DesignStyle is also an environment value:

```swift
let style = DesignStyle(id: "brand") {
    .surface {
        .cardRadius("18px")
        .cardShadow("none")
    }
    .button {
        .radius("999px")
    }
}

content
    .environment(\.theme, .system)
    .environment(\.designStyle, style)
```

There should be no `ThemeProvider`, `DesignStyleProvider`, or separate context modifier. Environment is the single propagation mechanism for values used by both server rendering and client hydration.

| Value | Responsibility | Defaulting model |
|---|---|---|
| `Theme` | Semantic color mode and color role values | Built-in `.system`, `.light`, and `.dark` values |
| `DesignStyle` | Component-wide shape, spacing, material, control, and motion values | Complete `.default`; third-party styles override only changed token groups |

`Theme` and `DesignStyle` are intentionally separate. Dark and light mode change color roles. DesignStyle changes component language, such as Material-like controls or glass-like surfaces. A custom DesignStyle must be built by overriding `DesignStyle.default`, so every component keeps a defined fallback token.

```mermaid
flowchart LR
    A["Theme"] --> B["color role CSS variables"]
    C["DesignStyle"] --> D["component CSS variables"]
    B --> E["ThemeStylesheet"]
    D --> E
    E --> F["SwiftWebUI component classes"]
```

When both values are set through modifiers, place `designStyle` outside the theme scope:

```swift
content
    .environment(\.theme, .dark)
    .environment(\.designStyle, .liquidGlass)
```

Modifier order is semantic. The stylesheet scope created by `theme` reads outer environment values, then renders the scoped content.

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
7. Keep raw `HTMLAttribute`, `Style.custom(_:_:)`, and `Stylesheet` APIs as escape hooks below the SwiftWebUI layer.
8. Keep `DesignStyle.default` complete and make presets or third-party styles override that default through the builder DSL.

## Current Implementation

| Area | Implemented |
|---|---|
| Modifier graph | `ComponentModifier`, `ModifierContent`, and `ModifiedContent` live in `SwiftHTML`. |
| Style abstraction | `WebShapeStyle`, `SemanticShapeStyle`, `CSSShapeStyle`, `ResolvedStyle`, and style modifiers live in `SwiftWebUI`. |
| Style modifiers | `foregroundStyle`, `backgroundStyle`, `tint`, and `border` are available on all `HTML`. |
| Stylesheet output | SwiftHTML owns `Style`, generated standard CSS property helpers, `Stylesheet`, `CSSRule`, and `@StylesheetBuilder`; SwiftWebUI uses them for typed theme CSS. |
| Design style | `DesignStyle`, built-in presets, environment propagation, and builder-based overrides live in `SwiftWebUI`. |
| Control environment | `isEnabled`, `controlSize`, `controlState`, `tint`, and `buttonStyle` are environment values. |
| Control styles | `ButtonStyleKind` provides built-in `automatic`, `bordered`, `borderedProminent`, and `plain` styles. |
| Binding-first controls | `TextField`, `Toggle`, `Slider`, `Stepper`, and `Picker` accept `Binding` values. |
| Typography | `Font`, `FontWeight`, and `FontDesign` provide SwiftUI-style text modifiers. |
| Navigation | `NavigationStack`, `NavigationLink`, `NavigationPath`, and `navigationTitle` are graph-level hooks. |
| Accessibility | Common accessibility modifiers map to semantic/ARIA attributes. |

This keeps SwiftHTML responsible for rendering correctness and keeps SwiftWebUI responsible for developer-facing UI ergonomics.
