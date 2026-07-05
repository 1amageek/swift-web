# SwiftWebUI Storyboard — Information Architecture

This defines **what every component page shows** and **how it is structured**, so
every component is implemented from one shared template and stays consistent.
The control panel is one part of this — not the whole.

## 1. Page anatomy

Every component page has the identical structure. Only the *data* differs.

```
┌───────────────────────────────────────────────────────────────────┐
│ TopBar   brand · search · Docs · GitHub · [Light|Dark]  (no fill)  │
├──────────┬─────────────────────────────────────────┬──────────────┤
│ Sidebar  │ Detail (max-width 860, left-aligned)     │ Inspector    │
│ (nav,    │                                          │ "On this     │
│  scroll) │  ① Header                                │  page"       │
│          │     breadcrumb · Title · summary         │  · Variants  │
│          │  ──────────────────────────────────────  │  · Playground│
│          │  ② Variants — static gallery of the      │  · Usage     │
│          │     whole range, no knobs                │  · Properties│
│          │  ③ Playground                            │  · Related   │
│          │     ┌────────────────────────────────┐   │              │
│          │     │ dot-grid canvas (live demo)     │   │ (anchors to  │
│          │     ├────────────────────────────────┤   │  each ②–⑦)  │
│          │     │ Control panel (per-component)   │   │              │
│          │     └────────────────────────────────┘   │              │
│          │  ④ Usage      — code snippet (per knob)   │              │
│          │  ⑤ DOM Contract — stable class hooks      │              │
│          │  ⑥ Properties — param/modifier table      │              │
│          │  ⑦ Related    — sibling component links   │              │
└──────────┴─────────────────────────────────────────┴──────────────┘
```

| # | Section | Content | Source of truth |
|---|---|---|---|
| ① | Header | breadcrumb (Category / Name), H1, one-line summary | static data |
| ② | Variants | a **static gallery** showing the component's whole range at a glance; no knobs — read it, then drive one config live in the Playground | `variants` (authored markup) |
| ③ | Playground | dot-grid canvas with the **live, centered demo** + the **control panel** whose knobs reproduce every Variant | `demo(state)` + `controls` |
| ④ | Usage | a usage example **generated from the live control state**, so changing a knob updates the code | `snippet(state)` |
| ⑤ | DOM Contract | stable semantic and utility classes emitted by the demo; internal atom classes/runtime attributes omitted | `contract(render(demo(state)))` |
| ⑥ | Properties | table: name · type · description | static data |
| ⑦ | Related | up to 3 sibling components in the same category | static data |

Variants and the Playground are the two halves of one idea: the gallery lets a
reader see the whole range at a glance, and the Playground lets them drive any
one configuration live. Every axis a Variant demonstrates is exposed as a
Playground knob, so the reader can reproduce and tweak what they saw.

## 2. Unified component model

Each component is **one declarative record** — no per-component layout code.

```
StoryboardComponent {
    id:         String                    // route slug
    category:   String                    // for breadcrumb + Related
    name:       String                    // H1
    summary:    String                    // one line under the title
    variants:   [Variant]                 // ② static gallery cards
    controls:   [Control]                 // ③ control panel knobs
    properties: [Property]                // ⑥ name, type, description
    related:    [String]                  // ⑦ sibling ids
    demo:       (State) -> some HTML       // ③ live preview, reads State
    snippet:    (State) -> String         // ④ usage example, reads State
}
```

`State` is the component's own values (the things its controls mutate). The
**demo is the single source of truth for behaviour**: the DOM Contract (⑤) is
*generated from the demo*, then normalized to public class hooks so it can never
drift while avoiding internal atom/hash noise. The Usage snippet (④) is likewise
generated from the live control state, so it stays in lock-step with the preview
— changing a knob updates the code. The Variants (②) are the one authored,
static part: hand-written cards that show the whole range at a glance. The shared
template renders ①–⑦ identically for all.

## 3. Control vocabulary

Six widgets cover every component. The panel is a horizontal flex row (wraps);
each control is `LABEL (uppercase) + widget`, separated from the canvas by a top
rule. This fixed set is what makes every panel look and behave the same.

| Control | Binds | Widget | Example uses |
|---|---|---|---|
| `segmented(label, options)` | enum (String) | pill group | font, alignment, spacing, listStyle, style, size, axis, context |
| `text(label, placeholder)` | String | text field | Content, Title, Query, action, message |
| `toggle(label)` | Bool | switch | isOn, disabled, isExpanded, showsLineNumbers, indeterminate |
| `range(label, min…max, step)` | Double | slider + readout | value, opacity, height |
| `swatch(label, palette)` | semantic color | color dots | foregroundStyle, tint |
| `color(label)` | hex string | color well | .css(_:), selection |

## 4. Per-component controls

Each component exposes the knobs that make its meaningful axes drivable, so the
Playground can **reproduce every Variant** in its gallery. The full, current map
is code, not prose — `storyboardControls(for:)` (with initial values in
`storyboardControlDefaults`) is the single source of truth. It is deliberately
not duplicated here, where it would drift (see "Generate, don't duplicate").

Authoring rule for a component's controls:

- **Cover the Variant axes.** For every dimension a Variant demonstrates — a
  style, a size, a tint, a boolean like `disabled`, a count, an element — add
  the matching knob so the reader can dial to that configuration. A Variant that
  is a bespoke composition (not reducible to knobs) stays gallery-only.
- **Use the canonical name.** A knob's label is the real API spelling
  (`controlSize`, `displayedComponents`, `textFieldStyle`, `as`) and its options
  are the real cases, so the generated snippet echoes them verbatim.
- **Stay within the six widgets.** Everything a component needs is expressible as
  segmented / text / toggle / range / swatch / color; no component invents a
  widget.

Representative shapes (see the code for the complete, authoritative list):

| id | controls |
|---|---|
| typography | txt Text · seg font · seg fontWeight · seg alignment · sw foregroundStyle · seg as [p/span/h3/code] |
| materials | seg material · seg glass [.regular/.clear] · seg tint · seg shape [Capsule/Rect] · tgl interactive |
| button-styles | txt Content · seg Style [Glass/Prominent/Bordered/Bordered+/Plain] · seg controlSize · sw Tint · tgl disabled |
| datepicker | seg displayedComponents [.date/.hourAndMinute/Both] · tgl disabled |
| slider | rng value · tgl stepped · sw tint · tgl disabled |

## 5. Consistency principles

- **One template, many records.** Sections ①–⑦ are rendered once by a shared
  template; a component contributes only data + its `demo`/`snippet` closures.
  No component writes its own page layout.
- **Generate, don't duplicate.** Anything that mirrors derived output is stale by
  construction. Both the DOM Contract and the Usage snippet are **generated from
  the live control state**, then the DOM Contract is filtered to stable public
  class hooks — so neither has to be synced by hand. The Variants gallery is the
  one authored, static artifact; everything else follows the demo. This principle
  is why the per-component control list lives in `storyboardControls(for:)`, not
  in this document.
- **Fixed widget set.** Every control is one of the six widgets, so all panels
  look and behave the same regardless of component.
- **The panel is always present** when a component declares controls — which is
  essentially every component, since each exposes its Variant axes as knobs.
