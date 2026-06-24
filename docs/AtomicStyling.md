# SwiftWebUI Atomic Styling — Design

## Goal

Emit **class-based** markup, not inline `style="…"`. The rendered HTML a component
produces should read like `<div class="swui-frame swui-fill-h swui-jc-center swui-p-m">`
with all declarations living in stylesheets — never `style="padding: …; justify-content: …"`.

This is the "Tailwind philosophy" built into the framework: every declaration becomes a
small, reusable class. It is **self-contained** — a SwiftWebUI app needs no Tailwind
toolchain, CDN, or build step — and it integrates with the existing `--swui-*` design
tokens and the ~243 semantic classes already in `ThemeStylesheet`.

## Goal state (definition of done)

The migration is complete when **all** of the following hold — each is verifiable:

**Output**
- Server-rendered HTML **and** the client-reconciled live DOM contain **no `style="…"`
  attribute**.
- Every declaration is expressed as a class — token utilities (`swui-p-m`, `swui-jc-center`,
  `swui-fg-accent`) or generated atomic classes (`swui-w-237px`, `swui-o-60`, `swui-x-{hash}`)
  — and the rules live in `<head>` (`<style id="swui-base">` / `<style id="swui-atomic">`).
- The storyboard **"Rendered HTML" panel shows clean, class-based markup** (the original trigger).

**Behaviour / parity**
- The rendered result is **visually identical** to pre-migration — no design regression —
  spot-checked across components in the browser, light + dark.
- Changing any control still updates **Preview + Usage + Rendered HTML** together; a new
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

### Tier 1 — Token utilities (static)
Predefined classes for the bounded token API, emitted once into `ThemeStylesheet`,
referencing `--swui-*` tokens:

| Modifier (token form) | Class | Rule |
|---|---|---|
| `.padding(.medium)` | `swui-p-m` | `padding: var(--swui-space-md)` |
| `.padding(.top, .small)` | `swui-pt-s` | `padding-top: var(--swui-space-sm)` |
| alignment `justify=center` | `swui-jc-center` | `justify-content: center` |
| `.foregroundStyle(.accent)` | `swui-fg-accent` | `color: var(--swui-accent)` |
| `.background(.regularMaterial)` | (existing `swui-material-regular`) | — |

No registry needed — these are static and cacheable.

### Tier 2 — Atomic classes (generated at render)
For arbitrary values, the modifier computes a **deterministic** class name from the
declaration, registers the rule, and returns the class:

| Modifier (arbitrary form) | Class | Rule (registered) |
|---|---|---|
| `.frame(width: 237)` | `swui-w-237` | `width: 237px` |
| `.opacity(0.6)` | `swui-o-60` | `opacity: 0.6` |
| `.cornerRadius(.px(13))` | `swui-r-13` | `border-radius: 13px` |
| `.background(Color(hex: 0x22a06b))` | `swui-x-{fnv1a}` | `background: #22a06b` |
| `.shadow(radius: 8, y: 10)` | `swui-x-{fnv1a}` | `box-shadow: 0 10px 8px …` |

Naming: the key is the **canonicalized `(property, value, unit)` triple**, never the
number alone — `Length` carries `px`/`em`/`%`/`vw`/… (`Length.swift`), so `13px` and
`13em` MUST map to different classes (`swui-r-13px` vs `swui-r-13em`). Canonicalization:
trim trailing-zero decimals (`13.0px` → `13px`), `%` → `pct`, negative → `n` prefix,
decimal point → `_`, unitless stays bare (`opacity 0.6` → `swui-o-60`). Readable form for
simple numerics; FNV-1a hash for complex declarations (color, shadow, gradient, transform).
The naming function is **pure** so the server and the WASM client compute the same class
for the same declaration → dedup is automatic across SSR + hydration.

## StyleRegistry — the collector

```swift
// Render-scoped, deduplicated map of atomic class -> validated rule body.
final class StyleRegistry: Sendable {            // Mutex-backed storage
    // Accepts a TYPED Style (declarations), never raw property/value strings.
    func register(_ style: Style) -> String      // validates, returns class name
    func rules() -> [(className: String, body: String)]            // for emission
}

@TaskLocal static var current: StyleRegistry?    // bound per render, like Transaction.current
```

- Atomic modifiers call `StyleRegistry.current?.register(...)`; token modifiers map to
  static class names and never touch the registry.
- Bound once per render pass (server) and per reconcile (client), mirroring the existing
  `Transaction.current` `@TaskLocal` pattern.

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

## Inline-style sources — ALL must migrate

Inline `style="…"` is produced by **three** paths today, not one. Targeting only
`styleAttribute` leaves the other two, so Phase 4's "no `style=`" holds only if all migrate:

| Source | Where | Migration |
|---|---|---|
| `styleAttribute(_:)` | modifier layer (`.opacity`/`.padding`/`.frame`/`.shadow`/…) — `WebUIComponentModifiers.swift` | token utility class, or `atom(Style)` |
| `mergedAttributes(class:styles:extra:)` | component-internal base styling — `SwiftWebUIAttributes.swift:22,48` (Frame, stacks, …) | the component's base `Style` routes through the registry |
| public `.style(_:)` / `.style { }` | WebUI modifier and low-level SwiftHTML typed style attributes | atomize the `Style`'s declarations through `atom` or the render-time attribute transformer |
| component-local custom properties (`--swui-w`, `--swui-animation`) | set inline today | atom — a custom-property declaration is just another validated declaration |

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

The page renderer renders the body first (modifiers fill `StyleRegistry.current`), then
assembles the document with the collected atomic rules:

```
<head>
  <style id="swui-base">…ThemeStylesheet (semantic + token utilities)…</style>
  <style id="swui-atomic">…registry.rules() for this page, deduped…</style>
</head>
<body> …class-based markup, zero style="…"… </body>
```

**Injection point — required in `<head>` (or before the styled content).** Atomic rules for
arbitrary values exist in NO base sheet, so a *trailing* `<style>` would leave those elements
unstyled until it parses → FOUC / layout shift. Head (or pre-content) injection is therefore
**mandatory, not a fallback** (the earlier "trailing is fine, base prevents FOUC" claim was
wrong for arbitrary-value classes). This requires reconciling the current setup: the base
theme CSS is emitted **in-tree** by `ThemeScope` (`ThemeScope.swift:15`), not in `<head>` —
the base + atomic sheets must be hoisted into the head so both precede the content they
style. Collect-then-assemble (render body to a buffer, read the registry, build the head).

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

## Migration phases

1. **Foundation** — SwiftHTML typed declarations + typed style attribute payload;
   `StyleRegistry.withCurrent` (`@TaskLocal` plus enlarged-stack propagation, plus
   `HTMLAttributeTransformContext`) taking a
   **typed `Style`** with value validation; the pure canonical `(property, value, unit)`
   class-name function; `atom(Style)`; **hoist base + atomic `<style>` into `<head>`**
   (reconcile `ThemeScope`'s in-tree emission); the client direct-host flush.
2. **Token utilities** — generate the bounded utility classes into `ThemeStylesheet`;
   convert token modifiers (Space padding, alignment, semantic fg/bg) to emit them.
3. **Atomic — convert ALL inline sources**: arbitrary modifiers (frame width/height, opacity,
   cornerRadius, custom colors, shadow), `mergedAttributes(styles:)` component base styling,
   and public `.style(_:)` / typed SwiftHTML `.style(...)` → atomic classes.
4. **Enforce** — remove inline `styleAttribute` from the modifier + component layers; add a
   rendering test asserting a representative tree emits **no** `style="` attribute.

## Risks / notes

- `StyleRegistry.withCurrent` must be used on **server render, server action fragment,
  streaming render, and every client reconcile**, or atomic rules go unregistered. The
  binding is propagated into SwiftHTML's enlarged render stack.
- **CSS injection**: values now land in a `<style>` block, where `}` escapes the rule — the
  registry validates typed declarations and rejects unsafe values (see *Validation & safety*).
- **Head-hoist is a render-architecture change**, not just a styling tweak: the base CSS moves
  from `ThemeScope`'s in-tree `<style>` into `<head>` whenever a registry is bound. Direct
  isolated SwiftHTML renders may still use the in-tree fallback for test/debug visibility.
- Class-name collisions: namespaced + hashed; phase 4's test should include a collision check.
- The "Rendered HTML" storyboard panel now shows clean class-based markup (the original ask);
  the declarations live in `<style id="swui-atomic">` / the base sheet.
- Raw-`div` inline-CSS escape hatches that already exist (e.g. the materials demo, the dashed
  alignment frame) migrate to atomics or the base stylesheet.
