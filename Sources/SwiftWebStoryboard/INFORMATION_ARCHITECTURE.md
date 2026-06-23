# SwiftWebUI Storyboard — Information Architecture

This defines **what every component page shows** and **how it is structured**, so
every component is implemented from one shared template and stays consistent.
The control panel is one part of this — not the whole.

## 1. Page anatomy

Every component page has the identical structure. Only the *data* differs.

```
┌───────────────────────────────────────────────────────────────────┐
│ TopBar   brand · search · Docs · GitHub · [Light|Dark]             │
├──────────┬─────────────────────────────────────────┬──────────────┤
│ Sidebar  │ Detail (max-width 760, left-aligned)     │ Inspector    │
│ (nav,    │                                          │ "On this     │
│  scroll) │  ① Header                                │  page"       │
│          │     breadcrumb · Title · summary         │  · Preview   │
│          │  ──────────────────────────────────────  │  · Usage     │
│          │  ② Preview                               │  · Properties│
│          │     ┌────────────────────────────────┐   │  · Rendered  │
│          │     │ dot-grid canvas (live demo)     │   │  · Related   │
│          │     ├────────────────────────────────┤   │              │
│          │     │ Control panel (per-component)   │   │ (anchors to  │
│          │     └────────────────────────────────┘   │  each ②–⑥)  │
│          │  ③ Usage      — code snippet             │              │
│          │  ④ Properties — param/modifier table     │              │
│          │  ⑤ Rendered HTML — the real DOM emitted   │              │
│          │  ⑥ Related    — sibling component links   │              │
└──────────┴─────────────────────────────────────────┴──────────────┘
```

| # | Section | Content | Source of truth |
|---|---|---|---|
| ① | Header | breadcrumb (Category / Name), H1, one-line summary | static data |
| ② | Preview | dot-grid canvas with the **live, centered demo** + the **control panel** | `demo(state)` + `controls` |
| ③ | Usage | a **canonical usage example** for the component (stable documentation) | static data |
| ④ | Properties | table: name · type · description | static data |
| ⑤ | Rendered HTML | the actual DOM the demo emits — **generated from the demo** (never hand-written) | `render(demo(state))` |
| ⑥ | Related | up to 3 sibling components in the same category | static data |

## 2. Unified component model

Each component is **one declarative record** — no per-component layout code.

```
StoryboardComponent {
    id:         String                 // route slug
    category:   String                 // for breadcrumb + Related
    name:       String                 // H1
    summary:    String                 // one line under the title
    controls:   [Control]              // ② control panel knobs
    properties: [Property]             // ④ name, type, description
    related:    [String]               // ⑥ sibling ids
    demo:       (State) -> some HTML    // ② live preview, reads State
    snippet:    String                  // ③ canonical usage example (documentation)
}
```

`State` is the component's own values (the things its controls mutate). The
**demo is the single source of truth**: the Rendered HTML (⑤) is *generated from
the demo*, so it can never drift. The snippet (③) is stable documentation, not a
regenerated mirror of the demo — that keeps it from becoming a second thing to
sync. The shared template renders ①–⑥ identically for all.

## 3. Control vocabulary

Six widgets cover every component. The panel is a horizontal flex row (wraps);
each control is `LABEL (uppercase) + widget`, separated from the canvas by a top
rule. This fixed set is what makes every panel look and behave the same.

| Control | Binds | Widget | Example uses |
|---|---|---|---|
| `segmented(label, options)` | enum (String) | pill group | font, alignment, listStyle, style, size, axis, context |
| `text(label, placeholder)` | String | text field | Content, Title, Query, action, message |
| `toggle(label)` | Bool | switch | isOn, disabled, isExpanded, showsLineNumbers, indeterminate |
| `range(label, min…max, step)` | Double | slider + readout | value, opacity, height, minColumnWidth |
| `swatch(label, palette)` | semantic color | color dots | foregroundStyle, tint |
| `color(label)` | hex string | color well | .css(_:), selection |

## 4. Per-component control map

The control panel content is chosen per component to expose its meaningful
knobs. (Derived from the design.) `seg` = segmented, `txt` = text,
`tgl` = toggle, `rng` = range, `sw` = swatch, `col` = color.

### Foundations
| id | controls |
|---|---|
| gridsystem | seg columns [12/8/4] · seg gutter [.small/.medium/.large] · seg arrangement [Sidebar/Halves/Thirds/Full] |
| spacing | seg grid unit [4/8/16 px] |
| alignment | seg alignment [Leading/Center/Trailing] |
| hug-fill | seg fill alignment [Leading/Center/Trailing] |
| style | seg context [Standalone/In List/In Toolbar] |
| responsive | seg size class [Compact/Regular/Large] |
| safearea | seg context [Notch/Browser/Desktop] |

### Content
| id | controls |
|---|---|
| typography | txt Text · seg font [Large Title…Caption] · seg fontWeight [Regular…Bold] · seg alignment · sw foregroundStyle [.primary/.secondary/.accent/.danger] |
| image | seg systemName [star/bell/gear] |
| colorvalue | sw Color (palette) · rng opacity [0…1] |
| code | seg language [Swift/JSON/Bash] · tgl showsLineNumbers |

### Layout & organization
| id | controls |
|---|---|
| label | txt Title · seg systemImage [seal/heart/pin] |
| groupbox | txt Label · seg Padding [Compact/Regular/Roomy] |
| list | seg listStyle [Plain/Inset/Grouped/Inset Grouped/Sidebar] |
| section | txt Header · txt Footer |
| disclosuregroup | tgl isExpanded |
| grid | rng minColumnWidth [80…200 px] |
| lazy | seg Axis [LazyVStack/LazyHStack] |
| tabview | seg selection [Summary/Settings] |
| stacks | seg Axis [VStack/HStack] |
| spacer | seg Spacer [Leading/Between/Trailing] |
| divider | seg orientation [Horizontal/Vertical] |
| scrollview | seg axes [Vertical/Horizontal] · rng height [100…220 px] |
| toolbar | txt Primary |

### Menus & actions
| id | controls |
|---|---|
| button | txt Content · seg Prominence [Primary/Secondary] |
| button-styles | txt Content · seg Style [Glass/Prominent/Plain] |
| control-sizes | txt Content · seg Size [Mini/Small/Regular/Large] |
| button-states | txt Content · sw Tint · tgl disabled |
| links | txt Label · seg Style [Plain/Glass/Prominent] · sw Tint |
| menu | txt Label · tgl disabled |

### Navigation & search
| id | controls |
|---|---|
| navigationstack | txt navigationTitle |
| navigationlink | txt Label |
| searchable | txt Query |
| tabview | (see Layout) |

### Presentation
| id | controls |
|---|---|
| alert | tgl isPresented · txt message |
| sheet | tgl isPresented |
| scrollview | (see Layout) |

### Selection & input
| id | controls |
|---|---|
| textfield | txt Placeholder · seg .type [text/email/url] · seg textFieldStyle [Automatic/Plain/Rounded] |
| securefield | txt Value · seg textFieldStyle [Automatic/Plain/Rounded] |
| texteditor | txt Text |
| form | seg method [GET/POST] · txt action |
| toggle | txt Label · tgl isOn |
| slider | rng value [0…1] |
| stepper | rng value [0…8] |
| picker | seg Selection [List/Grid/Columns] · seg pickerStyle [Segmented/Menu] |
| datepicker | seg datePickerStyle [Compact/Graphical] · tgl .hourAndMinute |
| colorpicker | col selection |
| color | col .css(_:) |

### Status
| id | controls |
|---|---|
| progressview | rng value [0…1] · tgl indeterminate |
| gauge | rng value [0…1] |
| badge | txt Label · sw Tint |

## 5. Consistency principles

- **One template, many records.** Sections ①–⑥ are rendered once by a shared
  template; a component contributes only data + the `demo`/`snippet` closures.
  No component writes its own page layout.
- **Generate, don't duplicate.** Anything that mirrors derived output is stale by
  construction. The Rendered HTML is **generated from the demo** (the hand-written
  stub is removed), and the snippet is **documentation** — not a generator that
  re-mirrors the demo. Nothing derived has to be kept in sync by hand.
- **Fixed widget set.** Every control is one of the six widgets, so all panels
  look and behave the same regardless of component.
- **The panel is always present** when a component declares controls — which,
  per the map above, is essentially every component.
