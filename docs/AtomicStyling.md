# SwiftWebUI Atomic Styling — Design

## Goal

Emit **class-based** markup, not inline `style="…"`. The rendered HTML a component
produces should read like `<div class="swui-vstack swui-gap-sm swui-ai-center">`
with all declarations living in stylesheets — never `style="padding: …; justify-content: …"`.

This is the "Tailwind philosophy" built into the framework: every declaration becomes a
small, reusable class. It is **self-contained** — a SwiftWebUI app needs no Tailwind
toolchain, CDN, or build step — and it integrates with the existing `--swui-*` design
tokens and the semantic classes already in `RootStylesheet`.

The implementation goal state and remaining utility/variant work are tracked in
[`UtilityStylingGoalState.md`](UtilityStylingGoalState.md). That document is the
source of truth for the direct-CSS ban and Tailwind-like utility parity work.

## Current Contract

The atomic styling implementation is complete when **all** of the following hold — each is verifiable:

**Output**
- Server-rendered HTML **and** the client-reconciled live DOM contain **no `style="…"`
  attribute**.
- Every declaration is expressed as a class — token utilities (`swui-p-m`, `swui-jc-center`,
  `swui-fg-accent`) or generated atomic classes (`swui-w-237px-x<hash>`,
  `swui-o-0_6-x<hash>`, `swui-bg-x<hash>`)
  — and the rules live in `<head>` (`<style id="swui-base">` / `<style id="swui-atomic">`).
- The storyboard **DOM Contract panel shows clean, stable class-based markup**; generated
  atom/hash classes stay an internal transport detail.

**Behaviour / parity**
- The rendered result is **visually identical** to pre-migration — no design regression —
  spot-checked across components in the browser, light + dark.
- Changing any control still updates **Preview + Usage + DOM Contract** together; a new
  arbitrary value flushes a new atomic rule on the client and **no inline `style` reappears**.
- The SwiftUI-faithful modifier API (signatures + semantics) is **unchanged**.

**Safety / architecture**
- Declaration values are validated; an injecting value (containing `}` etc.) is **rejected**.
- Class names are a **pure function** of the canonical `(property, value, unit)`; server == client; deduped.
- **SwiftHTML exposes structure, not policy**: `Style` provides read-only typed declarations and
  `HTMLAttribute.style(_:)` preserves its typed payload. SwiftHTML also exposes a generic
  attribute-transform hook; SwiftWebStyle owns validation and atomic CSS policy.
- **No FOUC**: the stylesheets precede the content they style.

**Quality gates**
- All existing tests pass; `xcodebuild` clean.
- New tests: a representative tree emits **no `style=`**; an injecting value is rejected.

**Non-goals (explicitly out of scope)**
- No Tailwind dependency (self-contained); no build-time/purge step (runtime generation).
- No change to the visual design, nor to the SwiftUI-faithful public API surface.

## Why class-based is hard at runtime

Tailwind scans source at **build time** and emits only the classes it sees (JIT/purge).
SwiftWebUI renders HTML at **runtime** (server per request + client on reconcile), so it
cannot purge the same way. The split:

```
Token values  (.small/.medium, semantic colors, alignment … = a finite set)
    → predefined utility classes, defined ONCE in the static stylesheet

Arbitrary values  (width: 237, radius: 13px, custom hex, opacity 0.6 … = unbounded)
    → cannot be predefined. To stay class-based we GENERATE one atomic class per
      unique declaration at render time, deduplicated.
```

## Architecture — two tiers

SwiftWebStyle owns the shared style primitives used by both tiers:

| Primitive | Responsibility |
|---|---|
| `StyleClass` | One HTML class token plus its escaped CSS selector. It is a token primitive; Tailwind-like variant semantics belong to the utility/variant compiler defined in `UtilityStylingGoalState.md`. |
| `StyleClassList` | Ordered, de-duplicated class composition for framework and user utility classes. |
| `rule(StyleClass)` | Binds a static utility class to a typed `Style` rule without repeating selector strings. |
| `StyleRegistry` / `atom(_:)` | Runtime registration for unbounded arbitrary `Style` declarations. |

### Tier 1 — Token utilities (static)
Predefined classes for the bounded token API, emitted once into `RootStylesheet`,
referencing `--swui-*` tokens:

| Modifier (token form) | Class | Rule |
|---|---|---|
| `.padding(.small)` | `swui-p-sm` | `padding: var(--swui-space-sm)` |
| `.padding(.horizontal, .small)` | `swui-px-sm` | `padding-left/right: var(--swui-space-sm)` |
| `VStack(spacing: .small)` | `swui-gap-sm` | `gap: var(--swui-space-sm)` |
| default stack spacing | `swui-gap-stack` | `gap: var(--swui-stack-spacing)` |
| stack alignment `center` | `swui-ai-center` | `align-items: center` |
| grid alignment `leading` | `swui-ji-leading` | `justify-items: flex-start` |
| `.background(.regularMaterial)` | (existing `swui-material-regular`) | — |

No registry needed — these are static and cacheable.

### Tier 2 — Atomic classes (generated at render)
For arbitrary values, the modifier computes a **deterministic** class name from the
declaration, registers the rule, and returns the class:

| Modifier (arbitrary form) | Class | Rule (registered) |
|---|---|---|
| `.frame(width: 237)` | `swui-w-237px-x<hash>` | `width: 237px` |
| `.opacity(0.6)` | `swui-o-0_6-x<hash>` | `opacity: 0.6` |
| `.clipShape(.rect(cornerRadius: .px(13)))` | `swui-r-13px-x<hash>` | `border-radius: 13px` |
| `.background(Color(hex: 0x22a06b))` | `swui-bg-x<hash>` | `background: #22a06b` |
| `.shadow(radius: 8, y: 10)` | `swui-shadow-x<hash>` | `box-shadow: 0 10px 8px …` |

Naming: the key is the rendered `(property, value)` declaration, never the number alone.
`Length` carries `px`/`em`/`%`/`vw`/… (`Length.swift`), so `13px` and `13em` map to
different classes. Simple values are encoded for readability (`%` → `pct`, negative → `n`
prefix, decimal point → `_`); complex values use the hash-only form. A FNV-1a hash of the full
`property + ":" + value` is **always appended** (`swui-r-13px-x<hash>`, or `swui-x<hash>` when
the value is not a simple token), so two distinct declarations can never collide on one class —
the readable token is only a legibility prefix, the hash guarantees uniqueness. The naming
function is **pure** so the server and the WASM client compute the same class for the same
declaration → dedup is automatic across SSR + hydration.

## StyleRegistry — the collector

```swift
// Render-scoped, insertion-ordered, deduplicated collection of atomic rules.
public final class StyleRegistry: Sendable {     // Mutex-backed { order, bodies }
    // Iterates Style.declarations (typed) — never parses Style.cssText.
    public func register(_ style: Style) -> String   // validates, returns class names
    public func rules() -> [(className: String, body: String)]   // first-seen order
}

@TaskLocal public static var current: StyleRegistry?
```

- `register` validates each declaration (`preconditionFailure` on an unsafe value), derives
  the hashed class name, and stores the rule in **first-seen order** (cascade-correct for
  shorthand/longhand). A different rule body landing on the same class trips a `precondition`.
- **Binding the registry — `StyleRegistry.withCurrent(_:_:)`.** A plain `@TaskLocal` is not
  enough: SwiftHTML renders the graph on a **dedicated enlarged-stack thread** (`withEnlargedStack`,
  to survive deep trees), which a task-local does not cross. `withCurrent` therefore sets three
  things for one render: the `@TaskLocal current`, an `EnlargedStackContext` propagator that
  re-establishes the binding on the render thread, and an `HTMLAttributeTransformContext`
  carrying an `AtomicStyleAttributeTransformer`.
- The **transformer is the load-bearing conversion**: SwiftHTML calls it on every element's
  attributes during render, rewriting each typed `style` attribute into a registered class.
  So conversion happens uniformly at the render layer — modifier-level `atom(_:)` is the
  in-scope fast path. The supported SwiftWeb renderers bind a registry; low-level isolated
  SwiftHTML renders without a registry are a debug path, not the SwiftWebUI markup contract.

### Validation & safety (mandatory — `<style>` is not `style="…"`)
Moving declarations from an inline `style` attribute into a `<style>` block changes the
threat model: an inline value cannot escape its attribute, but a value containing `}` (or
`<`, `;`-injection, `/* */`, control chars) inside a `<style>` rule could **close the rule
and inject a new selector**. The registry MUST:
- accept a **typed `Style`** through `Style.declarations`, never parse `Style.cssText`;
- **validate property names** (CSS identifiers / custom properties only);
- **validate each value** against a CSS-value grammar / reject `}` `{` `<` `;`-outside-value
  `/*` and control characters — reject (fail loudly), never sanitize-and-continue;
- define **conflict handling**: the class name is derived from the canonicalized
  declaration, so the same declaration always yields the same name; a hash collision
  (different declaration, same name) is detected and surfaced, not silently merged.

## Style Sources

SwiftWeb routes every framework-owned style source through typed `Style` declarations and
atomic class registration:

| Source | Where | Contract |
|---|---|---|
| `StyleClass` / `StyleClassList` | finite framework and user utility classes — `SwiftWebStyle` | class tokens compose directly; rules are emitted via typed `rule(StyleClass)` |
| `styleAttribute(_:)` | modifier layer (`.opacity`/`.padding`/`.frame`/`.shadow`/…) — `WebUIComponentModifiers.swift` | token utility class, or `atom(Style)` |
| `mergedAttributes(class:styles:extra:)` | component-internal base styling — `SwiftWebUIAttributes.swift` | the component's base `Style` routes through the registry |
| public `.style(_:)` / `.style { }` | WebUI modifier and low-level SwiftHTML typed style attributes | atomize the `Style`'s declarations through `atom` or the render-time attribute transformer |
| component-local custom properties (`--swui-w`, `--swui-animation`) | per-instance style state | atom — a custom-property declaration is just another validated declaration |

`atom(_ style: Style) -> HTMLAttribute` validates + registers the declarations and returns
`.class("…")`. Additionally, `StyleRegistry.withCurrent` installs an
`HTMLAttributeTransformContext` transformer so low-level SwiftHTML attributes such as
`div(.style(.minWidth("12px")))` are also converted before serialization. Token-form modifiers
map to static utility class names and skip the registry.

`styleAttribute(_:)` remains as the internal adapter name, but it returns an atomic class.
String/raw `style` attributes are rejected inside a SwiftWeb render scope. Dynamic CSS must
flow through typed `Style` declarations so validation and atomic class registration still apply.

```swift
func opacity(_ v: Double) -> ModifiedContent<…> {
    modifier(HTMLAttributeModifier([atom(Style { .opacity(trimmedNumber(v)) })]))  // class, validated
}
```

## Server emission

`PageDocument` emits `<head>` with three HTML-comment markers — `<!--swui-base-->`,
`<!--swui-atomic-->`, `<!--swui-head-scripts-->`. The render fills `StyleRegistry.current`
(through the transformer); `HTMLResponse` then replaces each marker with `SwiftWebHeadAssets`
output built from the registry, with the CSP `nonce` applied. Comment markers are immune to
the `data-node` hydration markers that the renderer adds to real tags:

```
<head>
  <style id="swui-base">…RootStylesheet (semantic + token utilities)…</style>
  <style id="swui-atomic">…registry.rules() for this page, deduped…</style>
</head>
<body> …class-based markup, zero style="…"… </body>
```

**Injection point — required in `<head>` (or before the styled content).** Atomic rules for
arbitrary values exist in NO base sheet, so a *trailing* `<style>` would leave those elements
unstyled until it parses → FOUC / layout shift. Head (or pre-content) injection is therefore
**mandatory, not a fallback** (the earlier "trailing is fine, base prevents FOUC" claim was
wrong for arbitrary-value classes). The base root CSS therefore moved out of `StyleRoot`'s
in-tree `<style>` into the head's `<!--swui-base-->` marker (filled by
`SwiftWebHeadAssets.baseStyle`), so the base and atomic sheets both precede the content they
style — no buffer/two-pass needed, just marker replacement on the rendered string.

## Client (WASM) flush

The reconcile runs the same Swift modifiers, filling a client `StyleRegistry`. After the
DOM batch applies, the runtime flushes **new** rules into the live `<style id="swui-atomic">`:

```
on reconcile:
  bind StyleRegistry.current = clientRegistry
  render + diff + apply DOM batch
  for (cls, body) in clientRegistry.rules() where cls ∉ injectedClasses:
      append ".cls { body }" to <style id="swui-atomic">; injectedClasses.insert(cls)
```

A control changing `width: 237 → 300` produces class `swui-w-300`; its rule is injected
once, then reused. Deterministic names make the injected-set a simple dedup `Set`.

**Transport.** `HydrationRuntimeUpdate` still does not carry style rules. The client
`StyleRegistry` flushes directly through the DOM host (`JavaScriptKitBrowserRuntime`):
after the batch applies, the host injects new rules into `<style id="swui-atomic">` via
JavaScriptKit. If the server sends a new document or fragment with atomic styles, the host
also merges `swui-base` / `swui-atomic` from the parsed head.

## Integration with existing layers

- Semantic component classes (`swui-button`, `swui-text`, `swui-list`…), layout markers
  (`swui-fill-h`/`swui-hug-h`), and material/glass classes are **unchanged** — already class-based.
- The atomic layer replaces modifier, component-base, and typed SwiftHTML style declarations.
- `--swui-*` tokens are unchanged; utilities and atomics reference them.

## Implementation Status

| Area | Status |
|---|---|
| SwiftHTML typed declarations | Implemented: `Style.declarations` is public read-only structure. |
| Typed style payload | Implemented: `HTMLAttribute.style(_:)` preserves the `Style` payload. |
| Render-time attribute conversion | Implemented: `HTMLAttributeTransformContext` lets SwiftWeb atomize low-level typed `.style(...)`. |
| Server head emission | Implemented: `swui-base`, `swui-atomic`, and head scripts are emitted into `<head>`. |
| Client flush | Implemented: WASM updates append new atomic rules to `<style id="swui-atomic">`. |
| Utility class primitives | Implemented: `StyleClass`, `StyleClassList`, and `rule(StyleClass)` are the standard API for finite utility classes. |
| Utility variant compiler | Implemented for state pseudo-class, pseudo-element, `dark:`, default breakpoint, group, peer, data, aria, structural, container, arbitrary selector, arbitrary attribute, arbitrary value, named group/peer, and typed custom utility registration through `SwiftWebStyle`. |
| Theme token utilities | Implemented: SwiftWebUI emits `swui-bg-*`, `swui-fg-*`, border, radius, and shadow utilities from Theme-backed token namespaces. |
| Layer order | Implemented and tested: root tokens, component rules, utility rules, material rules, at-rules, then render-scoped atomic rules in `<style id="swui-atomic">`. |
| SwiftWebUI standard layout utilities | Implemented: stack/grid gap and alignment use `StyleClass` token utilities by default; arbitrary numeric spacing remains atomic. |
| Raw/string style handling | Enforced: SwiftWeb render scopes reject string/raw `style` attributes. |
| Tests | Implemented: representative page output has no `style="`; semicolon injection is rejected as an unsafe declaration. |

## Risks / notes

- `StyleRegistry.withCurrent` must be used on **server render, server action fragment,
  streaming render, and every client reconcile**, or atomic rules go unregistered. The
  binding is propagated into SwiftHTML's enlarged render stack.
- **CSS injection**: values now land in a `<style>` block, where `}` escapes the rule — the
  registry validates typed declarations and rejects unsafe values (see *Validation & safety*).
- **Head-hoist is a render-architecture change**, not just a styling tweak: the base CSS moves
  from `StyleRoot`'s in-tree `<style>` into `<head>` whenever a registry is bound. SwiftWeb
  page/action/stream/client render paths must bind the registry so component markup stays
  class-only and CSS stays in the stylesheet channel.
- Class-name collisions: namespaced + hashed; a collision with different rule bodies trips a precondition.
- The Storyboard DOM Contract panel shows stable class hooks; generated atom classes remain
  in the real transport DOM and live in `<style id="swui-atomic">`, but are not displayed as
  the public component contract.
- Raw/string `style` attributes inside a SwiftWeb render scope are rejected; low-level SwiftHTML
  can still render raw styles outside SwiftWeb policy.
