import SwiftHTML
import SwiftWebStyle

package enum RootStylesheet {
  private static func cls(_ name: String) -> StyleSelector {
    .class(StyleClass(name))
  }

  private static func el(_ element: StyleElement) -> StyleSelector {
    .element(element)
  }

  private static func list(_ selectors: StyleSelector...) -> StyleSelector {
    .list(selectors)
  }

  package static func stylesheet(for styleSystem: StyleSystem) -> Stylesheet {
    Stylesheet {
      rootTokenStylesheet(for: styleSystem)
      componentStylesheet
      utilityStylesheet
      materialStylesheet
      atRulesStylesheet
    }
  }

  private static func rootTokenStylesheet(for styleSystem: StyleSystem) -> Stylesheet {
    Stylesheet {
      // Scheme-independent theme tokens plus the light palette as the default.
      // Light is the baseline; an explicit dark scope or the OS dark preference
      // swaps only the color tokens.
      rule(cls("swui-root")) {
        baseTokenStyle
        lightPalette
      }
      // An explicit dark root overrides the light default. The selector is scoped
      // to SwiftWebUI roots so unrelated data attributes do not inherit palette
      // variables by accident.
      rule(cls("swui-root").attribute("data-color-scheme", equals: "dark")) {
        darkPalette
      }
      // A document that carries no explicit scheme follows the OS preference.
      media(.prefersColorScheme(.dark)) {
        rule(cls("swui-root").not(.attribute("data-color-scheme"))) {
          darkPalette
        }
      }
      rule(.attribute("data-style-system", equals: styleSystem.id)) {
        styleSystem.cssVariableStyle
      }
    }
  }

  /// The full stylesheet text. Every rule — including the `@supports`/`@media`/
  /// `@keyframes` at-rules — is modeled in the typed `Stylesheet`, so there is no
  /// raw CSS string.
  package static func css(for styleSystem: StyleSystem) -> String {
    stylesheet(for: styleSystem).cssText
  }

  // The color palettes are keyed by `ColorScheme`. The light palette is the
  // default; the dark palette applies under an explicit dark scope or the OS
  // dark preference. Only the color tokens differ between schemes — the radius,
  // spacing, and typography tokens are scheme-independent.
  private static var lightPalette: Style {
    Style {
      .custom("--swui-background", "#f7f8fa")
      .custom("--swui-surface", "#ffffff")
      .custom("--swui-surface-raised", "#ffffff")
      .custom("--swui-text", "#16181d")
      .custom("--swui-text-muted", "#626975")
      .custom("--swui-border", "#d9dee7")
      .custom("--swui-accent", "#1769e0")
      .custom("--swui-accent-text", "#ffffff")
      .custom("--swui-danger", "#c93636")
      .custom("--swui-danger-text", "#ffffff")
    }
  }

  private static var darkPalette: Style {
    Style {
      .custom("--swui-background", "#111318")
      .custom("--swui-surface", "#181b22")
      .custom("--swui-surface-raised", "#20242d")
      .custom("--swui-text", "#f4f6f8")
      .custom("--swui-text-muted", "#a8b0bd")
      .custom("--swui-border", "#343a46")
      .custom("--swui-accent", "#65a8ff")
      .custom("--swui-accent-text", "#07111f")
      .custom("--swui-danger", "#ff7777")
      .custom("--swui-danger-text", "#1f0707")
    }
  }

  private static var baseTokenStyle: Style {
    Style {
      .custom("--swui-radius-small", "4px")
      .custom("--swui-radius-medium", "8px")
      .custom("--swui-radius-large", "12px")
      .custom("--swui-radius-pill", "999px")
      .custom("--swui-space-xs", "4px")
      .custom("--swui-space-sm", "8px")
      .custom("--swui-space-md", "12px")
      .custom("--swui-space-lg", "16px")
      .custom("--swui-space-xl", "24px")
      .custom(
        "--swui-font-family",
        "-apple-system, BlinkMacSystemFont, \"SF Pro Text\", \"SF Pro Display\", system-ui, sans-serif"
      )
      .custom(
        "--swui-mono-font-family",
        "\"JetBrains Mono\", ui-monospace, \"SFMono-Regular\", \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace"
      )
      .custom("--swui-base-size", "16px")
      .custom("--swui-line-height", "1.5")
    }
  }

  private static var componentStylesheet: Stylesheet {
    Stylesheet {
      rule(list(el(.html), el(.body))) {
        .minHeight("100%")
      }
      rule(el(.body)) {
        .margin("0")
      }
      rule(cls("swui-root")) {
        .minHeight("100%")
          .display("flex")
          .flexDirection("column")
          .alignItems("stretch")
          .color("var(--swui-text)")
          .background("var(--swui-background)")
          .fontFamily("var(--swui-font-family)")
          .fontSize("var(--swui-base-size)")
          .lineHeight("var(--swui-line-height)")
      }
      // A root scope nested inside another (`.preferredColorScheme(_:)` applied
      // to a subtree, e.g. a preview matrix cell) is an inner surface, not the
      // page canvas. It keeps the scheme background so the subtree previews on
      // its own scheme, but drops the page-root fills: it sizes to its content
      // instead of stretching to `min-height: 100%` (which would overrun
      // siblings), rounds its corners so the scheme fill frames a rounded
      // container instead of poking square corners past it, and pads its content
      // so elevation is not clipped at a hard background seam.
      rule(cls("swui-root").descendant(cls("swui-root"))) {
        .minHeight("auto")
          .borderRadius("var(--swui-radius-large)")
          .padding(.space(.medium))
      }
      // A page opts into a viewport-filling surface by setting the document body
      // class to `swui-viewport`: the body is sized to the viewport and clips its
      // own overflow, so a descendant ScrollView scrolls internally (with native
      // bounce) instead of the whole page scrolling.
      rule(el(.body).compound(cls("swui-viewport"))) {
        .height("100dvh")
          .overflow("hidden")
      }
      rule(el(.body).compound(cls("swui-viewport")).child(cls("swui-root"))) {
        .height("100%")
          .minHeight("0")
      }
      rule(list(
        cls("swui-vstack"),
        cls("swui-hstack"),
        cls("swui-lazy-vstack"),
        cls("swui-lazy-hstack"),
        cls("swui-toolbar")
      )) {
        .display("flex")
          .boxSizing("border-box")
      }
      rule(list(cls("swui-vstack"), cls("swui-lazy-vstack"))) {
        .flexDirection("column")
      }
      rule(list(
        cls("swui-hstack"),
        cls("swui-lazy-hstack"),
        cls("swui-toolbar")
      )) {
        .flexDirection("row")
          .alignItems("center")
          // SwiftUI's HStack lays its children on a single row and never wraps
          // (wrapping is Grid/ViewThatFits territory). Match that so a row of
          // controls stays one line and overflows rather than dropping onto a
          // second row.
          .flexWrap("nowrap")
      }
      rule(list(
        cls("swui-lazy-vstack").child(.universal),
        cls("swui-lazy-hstack").child(.universal)
      )) {
        .contentVisibility("auto")
          .containIntrinsicSize("var(--swui-lazy-intrinsic-size)")
      }
      rule(list(cls("swui-lazy-vgrid"), cls("swui-lazy-hgrid"))) {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(list(
        cls("swui-lazy-vgrid").child(.universal),
        cls("swui-lazy-hgrid").child(.universal)
      )) {
        .contentVisibility("auto")
          .containIntrinsicSize("var(--swui-lazy-intrinsic-size)")
      }
      rule(cls("swui-zstack")) {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(cls("swui-zstack").child(.universal)) {
        .gridArea("1 / 1")
      }
      rule(cls("swui-frame")) {
        .display("flex")
      }
      // `.animation(_:value:)` wraps its subtree in this scope, which carries the
      // inherited `--swui-animation` custom property without adding a box.
      rule(cls("swui-animation-scope")) {
        .display("contents")
      }
      // Every element inside an animation scope transitions *every* animatable
      // property at the scope's `--swui-animation` timing (instant when no
      // `.animation(_:)` is in scope, via the `0s` fallback). This is what makes
      // `.animation` apply subtree-wide — the way SwiftUI does, animating whatever
      // a descendant changes (color, backdrop-filter, layout, …) — rather than
      // only a hand-picked few. Declared before the control rules so a control's
      // own transition still wins on its element.
      rule(cls("swui-animation-scope").descendant(.universal)) {
        .transition("all var(--swui-animation, 0s)")
      }
      // `.transition(_:)` insertion/removal. The "from" state is published as
      // --swui-enter-*/--swui-exit-* custom properties on the element; insertion
      // animates from the @starting-style values (below) and removal animates to
      // the exit values once the runtime adds `.swui-exiting`.
      rule(cls("swui-transition")) {
        .transition(
          "opacity var(--swui-transition, 0.3s ease), "
            + "transform var(--swui-transition, 0.3s ease)"
        )
      }
      rule(cls("swui-transition").compound(cls("swui-exiting"))) {
        .opacity("var(--swui-exit-opacity, 1)")
          .transform("var(--swui-exit-transform, none)")
      }
      rule(cls("swui-layered")) {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(cls("swui-layered").child(cls("swui-layer"))) {
        .gridArea("1 / 1")
          .boxSizing("border-box")
      }
      rule(cls("swui-layer-background")) {
        .zIndex("0")
      }
      rule(cls("swui-layer-content")) {
        .zIndex("1")
      }
      rule(cls("swui-layer-overlay")) {
        .zIndex("2")
      }
      rule(cls("swui-spacer")) {
        .flex("1 1 auto")
      }
      rule(cls("swui-grid")) {
        .display("grid")
          .width("fit-content")
          .rowGap("var(--swui-grid-vertical-spacing)")
          .boxSizing("border-box")
      }
      // SwiftUI Grid lays each GridRow's cells into auto-sized columns; mirror
      // that with a per-row column grid (a real `display: grid`, not a table).
      // Equal-width cells line up across rows.
      rule(cls("swui-grid-row")) {
        .display("grid")
          .custom("grid-auto-flow", "column")
          .custom("grid-auto-columns", "minmax(0, max-content)")
          .custom("column-gap", "var(--swui-grid-horizontal-spacing)")
          .alignItems("var(--swui-grid-cell-vertical-alignment)")
      }
      rule(cls("swui-grid-system")) {
        .display("grid")
          .gridTemplateColumns("repeat(var(--swui-grid-system-columns), minmax(0, 1fr))")
          .columnGap(.gridSystemGutter)
          .rowGap("var(--swui-grid-system-gutter)")
        .width("100%")
          .boxSizing("border-box")
          .margin("0 auto")
          .paddingInline(.pageInlinePadding)
      }
      rule(cls("swui-grid-pane")) {
        .boxSizing("border-box")
          .minWidth("0")
      }
      // GroupBox composes the shared material primitive and keeps only the
      // container chrome: padding, border, radius, and the elevated drop shadow.
      rule(cls("swui-group-box")) {
          .display("flex")
          .flexDirection("column")
          .alignItems("flex-start")
          .border("var(--swui-container-border)")
          .borderRadius("var(--swui-container-radius)")
          .boxSizing("border-box")
          .boxShadow("var(--swui-container-shadow)")
          .padding(.space(.medium))
      }
      rule(cls("swui-group-box-title")) {
        .margin("0 0 var(--swui-space-sm) 0")
      }
      // The toolbar reads as a floating glass bar: its fill + backdrop come
      // from the shared `bar` material (composed in `Toolbar`); this rule
      // adds the padding and radius that give the bar its shape.
      rule(cls("swui-toolbar")) {
        .padding(.space(.small), .space(.medium))
          .borderRadius("var(--swui-radius-large)")
      }
      rule(cls("swui-mapkit-map")) {
        .position("relative")
          .display("block")
          .width("calc(100% - (var(--swui-space-lg) * 2))")
          .minHeight("236px")
          .aspectRatio("4 / 3")
          .margin("var(--swui-space-sm) var(--swui-space-lg) var(--swui-space-md)")
          .overflow("hidden")
          .border("1px solid color-mix(in srgb, var(--swui-border) 82%, var(--swui-accent))")
          .background("linear-gradient(135deg, color-mix(in srgb, var(--swui-surface-raised) 92%, var(--swui-accent)), color-mix(in srgb, var(--swui-background) 88%, var(--swui-accent)))")
          .borderRadius("var(--swui-container-radius)")
          .isolation("isolate")
      }
      rule(cls("swui-mapkit-map").descendant(cls("mk-map-view"))) {
        .borderRadius("inherit")
      }
      rule(cls("swui-mapkit-placeholder")) {
        .position("absolute")
          .inset("0")
          .display("grid")
          .alignItems("end")
          .padding(.space(.large))
          .background("linear-gradient(180deg, color-mix(in srgb, var(--swui-surface-raised) 8%, transparent), color-mix(in srgb, var(--swui-surface-raised) 82%, transparent))")
      }
      rule(cls("swui-mapkit-placeholder-body")) {
        .display("grid")
          .gap(.space(.xsmall))
          .maxWidth("280px")
          .padding(.space(.medium), .space(.large))
          .border("1px solid color-mix(in srgb, var(--swui-border) 86%, var(--swui-text))")
          .background("color-mix(in srgb, var(--swui-surface-raised) 94%, transparent)")
          .borderRadius("var(--swui-container-radius)")
          .boxShadow("0 8px 22px color-mix(in srgb, var(--swui-text) 7%, transparent)")
      }
      rule(cls("swui-mapkit-placeholder").descendant(cls("swui-mapkit-placeholder-body").descendant(cls("swui-mapkit-eyebrow")))) {
        .color("var(--swui-accent)")
          .fontSize("11px")
          .fontWeight("900")
          .letterSpacing("0")
          .textTransform("uppercase")
      }
      rule(cls("swui-mapkit-placeholder").descendant(el(.strong))) {
        .color("var(--swui-text)")
          .fontSize("15px")
          .lineHeight("1.35")
          .overflowWrap("anywhere")
      }
      rule(cls("swui-mapkit-placeholder").descendant(el(.small))) {
        .color("var(--swui-text-muted)")
          .fontSize("12px")
          .fontWeight("700")
          .lineHeight("1.45")
          .overflowWrap("anywhere")
      }
      rule(cls("swui-mapkit-error")) {
        .background("linear-gradient(180deg, color-mix(in srgb, var(--swui-surface-raised) 10%, transparent), color-mix(in srgb, var(--swui-danger) 8%, var(--swui-surface-raised)))")
      }
      media(.maxWidth("360px")) {
        rule(cls("swui-mapkit-map")) {
          .width("calc(100% - 20px)")
            .minHeight("210px")
            .marginLeft("10px")
            .marginRight("10px")
        }
      }
      rule(cls("swui-label-style-titleOnly").descendant(cls("swui-label-icon"))) {
        .display("none")
      }
      // Icon-only labels hide the title visually but keep it in the
      // accessibility tree (the icon itself is aria-hidden), so the control
      // still has an accessible name.
      rule(cls("swui-label-style-iconOnly").descendant(cls("swui-label-title"))) {
        .position("absolute")
          .width("1px")
          .height("1px")
          .padding(.zero)
          .margin("-1px")
          .overflow("hidden")
          .clipPath("inset(50%)")
          .whiteSpace("nowrap")
          .border("0")
      }
      rule(list(
        cls("swui-text-field-style-plain"),
        cls("swui-text-editor").compound(cls("swui-text-field-style-plain"))
      )) {
        .background("transparent")
          .border("0")
          .boxShadow("none")
      }
      rule(cls("swui-text-field-style-squareBorder")) {
        .borderRadius("0")
      }
      rule(cls("swui-list-style-plain")) {
        .border("0")
          .background("transparent")
      }
      rule(list(cls("swui-list-style-grouped"), cls("swui-list-style-insetGrouped"))) {
        .padding(.space(.small))
          .borderRadius("var(--swui-radius-large)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 72%, transparent)")
      }
      rule(cls("swui-toggle-style-checkbox").descendant(cls("swui-toggle-control"))) {
        .borderRadius("var(--swui-radius-small)")
      }
      rule(cls("swui-tabview-style-page").descendant(cls("swui-tab-item"))) {
        .display("none")
      }
      // MARK: Sizing intent markers (parent-axis aware)
      // Horizontal fill under a column parent -> stretch the cross axis.
      rule(list(
        cls("swui-vstack").child(cls("swui-fill-h")),
        cls("swui-lazy-vstack").child(cls("swui-fill-h")),
        cls("swui-group-box").child(cls("swui-fill-h")),
        cls("swui-zstack").child(cls("swui-fill-h")),
        cls("swui-frame").child(cls("swui-fill-h")),
        cls("swui-scroll-view").child(cls("swui-fill-h")),
        cls("swui-root").child(cls("swui-fill-h"))
      )) {
        .alignSelf("stretch")
      }
      // Horizontal fill under a row parent -> grow along the main axis.
      rule(list(
        cls("swui-hstack").child(cls("swui-fill-h")),
        cls("swui-lazy-hstack").child(cls("swui-fill-h")),
        cls("swui-toolbar").child(cls("swui-fill-h"))
      )) {
        .flex("1 1 0%")
          .minWidth("0")
      }
      // Vertical fill under a row parent -> stretch the cross axis.
      rule(list(
        cls("swui-hstack").child(cls("swui-fill-v")),
        cls("swui-lazy-hstack").child(cls("swui-fill-v")),
        cls("swui-toolbar").child(cls("swui-fill-v"))
      )) {
        .alignSelf("stretch")
      }
      // Vertical fill under a column parent -> grow along the main axis.
      rule(list(
        cls("swui-vstack").child(cls("swui-fill-v")),
        cls("swui-lazy-vstack").child(cls("swui-fill-v")),
        cls("swui-group-box").child(cls("swui-fill-v")),
        cls("swui-frame").child(cls("swui-fill-v")),
        cls("swui-root").child(cls("swui-fill-v"))
      )) {
        .flex("1 1 0%")
          .minHeight("0")
      }
      // Upward propagation: a container holding a horizontal-fill
      // descendant is itself horizontally greedy in its column parent.
      rule(list(
        cls("swui-vstack").has(cls("swui-fill-h")),
        cls("swui-lazy-vstack").has(cls("swui-fill-h")),
        cls("swui-hstack").has(cls("swui-fill-h")),
        cls("swui-lazy-hstack").has(cls("swui-fill-h")),
        cls("swui-group-box").has(cls("swui-fill-h")),
        cls("swui-toolbar").has(cls("swui-fill-h"))
      )) {
        .alignSelf("stretch")
      }
      // A row that contains a Spacer is horizontally greedy; carry that
      // intent up to one enclosing column level.
      rule(list(
        cls("swui-hstack").hasChild(cls("swui-spacer")),
        cls("swui-toolbar").hasChild(cls("swui-spacer")),
        cls("swui-group-box").has(cls("swui-hstack").child(cls("swui-spacer"))),
        cls("swui-group-box").has(cls("swui-toolbar").child(cls("swui-spacer"))),
        cls("swui-vstack").has(cls("swui-hstack").child(cls("swui-spacer"))),
        cls("swui-vstack").has(cls("swui-toolbar").child(cls("swui-spacer")))
      )) {
        .alignSelf("stretch")
      }
      // Row-parent override: a greedy column/container that is itself a row
      // item grows on the main axis instead of stretching the cross axis.
      rule(list(
        cls("swui-hstack").child(cls("swui-vstack").has(cls("swui-fill-h"))),
        cls("swui-hstack").child(cls("swui-lazy-vstack").has(cls("swui-fill-h"))),
        cls("swui-hstack").child(cls("swui-group-box").has(cls("swui-fill-h"))),
        cls("swui-toolbar").child(cls("swui-vstack").has(cls("swui-fill-h"))),
        cls("swui-toolbar").child(cls("swui-group-box").has(cls("swui-fill-h")))
      )) {
        .flex("1 1 0%")
          .minWidth("0")
          .alignSelf("auto")
      }
      // A frame that fills an axis must let a CONTAINER child accept that
      // proposed size and fill too (SwiftUI merges the frame with the view, so a
      // VStack/HStack in a fill frame grows to the frame). Scoped to containers
      // so intrinsic content (Text, Image) is still positioned by the frame's
      // alignment rather than stretched. The frame is a flex row, so a
      // horizontal fill grows the main axis and a vertical fill stretches cross.
      rule(list(
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-vstack")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-hstack")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-lazy-vstack")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-lazy-hstack")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-zstack")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-group-box")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-scroll-view")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-grid-system")),
        cls("swui-frame").compound(cls("swui-fill-h")).child(cls("swui-frame"))
      )) {
        .flex("1 1 0%")
          .minWidth("0")
      }
      rule(list(
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-vstack")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-hstack")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-lazy-vstack")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-lazy-hstack")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-zstack")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-group-box")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-scroll-view")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-grid-system")),
        cls("swui-frame").compound(cls("swui-fill-v")).child(cls("swui-frame"))
      )) {
        .alignSelf("stretch")
          .minHeight("0")
      }
      // Explicit hug blocks fill and propagation. Declared after the
      // fill/:has rules so equal-specificity selectors win by source order.
      rule(cls("swui-hug-h")) {
        .alignSelf("flex-start")
      }
      rule(list(
        cls("swui-vstack").compound(cls("swui-hug-h")),
        cls("swui-lazy-vstack").compound(cls("swui-hug-h")),
        cls("swui-hstack").compound(cls("swui-hug-h")),
        cls("swui-lazy-hstack").compound(cls("swui-hug-h")),
        cls("swui-group-box").compound(cls("swui-hug-h")),
        cls("swui-toolbar").compound(cls("swui-hug-h"))
      )) {
        .alignSelf("flex-start")
      }
      rule(list(
        cls("swui-hstack").child(cls("swui-hug-h")),
        cls("swui-lazy-hstack").child(cls("swui-hug-h")),
        cls("swui-toolbar").child(cls("swui-hug-h"))
      )) {
        .flex("0 0 auto")
          .alignSelf("auto")
      }
      // A fixed-width column that also fills height (e.g. a scrollable sidebar):
      // hug-h pins the width via flex above, but fill-v must still stretch it to
      // the row height so an inner ScrollView is bounded and can scroll. More
      // specific than the hug-h rule, so the cross-axis stretch wins.
      rule(list(
        cls("swui-hstack").child(cls("swui-hug-h").compound(cls("swui-fill-v"))),
        cls("swui-lazy-hstack").child(cls("swui-hug-h").compound(cls("swui-fill-v"))),
        cls("swui-toolbar").child(cls("swui-hug-h").compound(cls("swui-fill-v")))
      )) {
        .alignSelf("stretch")
          .minHeight("0")
      }
      // Vertical hug, parent-axis aware.
      rule(list(
        cls("swui-vstack").child(cls("swui-hug-v")),
        cls("swui-lazy-vstack").child(cls("swui-hug-v")),
        cls("swui-group-box").child(cls("swui-hug-v")),
        cls("swui-root").child(cls("swui-hug-v"))
      )) {
        .flex("0 0 auto")
      }
      rule(list(
        cls("swui-hstack").child(cls("swui-hug-v")),
        cls("swui-lazy-hstack").child(cls("swui-hug-v")),
        cls("swui-toolbar").child(cls("swui-hug-v"))
      )) {
        .alignSelf("flex-start")
      }
      rule(cls("swui-heading")) {
        .margin("0")
          .color("var(--swui-text)")
          .letterSpacing("0")
      }
      rule(cls("swui-heading-page")) {
        .fontSize("var(--swui-heading-page-size)")
          .lineHeight("var(--swui-heading-page-line-height)")
      }
      rule(cls("swui-heading-section")) {
        .fontSize("var(--swui-heading-section-size)")
          .lineHeight("1.2")
      }
      rule(cls("swui-heading-subsection")) {
        .fontSize("var(--swui-heading-subsection-size)")
          .lineHeight("1.25")
      }
      rule(cls("swui-text")) {
        .margin("0")
          .color("var(--swui-text)")
      }
      rule(cls("swui-inline-code")) {
        .display("inline-block")
          .padding(.zero, .em(0.35))
          .border("1px solid var(--swui-border)")
          .borderRadius("var(--swui-radius-small)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 88%, var(--swui-accent))")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.9em")
          .lineHeight("1.5")
      }
      rule(cls("swui-preformatted")) {
        .maxWidth("100%")
          .overflowX("auto")
          .padding(.space(.medium))
          .border("1px solid var(--swui-border)")
          .borderRadius("var(--swui-radius-medium)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 92%, var(--swui-accent))")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.875em")
          .lineHeight("1.55")
          .tabSize("4")
          .whiteSpace("pre")
          .boxSizing("border-box")
      }
      rule(cls("swui-code-block")) {
        .maxWidth("100%")
          .margin("0")
          .overflowX("auto")
          .padding(.space(.medium), .zero)
          .border("1px solid var(--swui-border)")
          .borderRadius("var(--swui-radius-medium)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 92%, var(--swui-accent))")
          .color("var(--swui-text)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.875em")
          .lineHeight("1.55")
          .tabSize("4")
          .boxSizing("border-box")
      }
      rule(cls("swui-code-block-content")) {
        .display("block")
          .minWidth("max-content")
      }
      rule(cls("swui-code-line")) {
        .display("grid")
          .gridTemplateColumns("minmax(3ch, auto) 1fr")
          .columnGap(.space(.medium))
          .padding(.zero, .space(.medium))
          .whiteSpace("pre")
      }
      rule(cls("swui-code-line-plain")) {
        .gridTemplateColumns("1fr")
      }
      rule(cls("swui-code-line-number")) {
        .color("var(--swui-text-muted)")
          .fontVariantNumeric("tabular-nums")
          .textAlign("right")
          .userSelect("none")
      }
      rule(cls("swui-code-line-content")) {
        .whiteSpace("pre")
      }
      rule(cls("swui-button")) {
        .display("inline-flex")
          .alignItems("center")
          .justifyContent("center")
          .gap(.space(.small))
          .border("1px solid transparent")
          .borderRadius("var(--swui-button-radius)")
          .minHeight("var(--swui-control-regular-height)")
          .padding(.zero, .space(.large))
          .font("inherit")
          .cursor("pointer")
          .textDecoration("none")
          .whiteSpace("nowrap")
          .minWidth("max-content")
          .lineHeight("1")
          .boxSizing("border-box")
          .transition(
            "background var(--swui-animation, var(--swui-motion-quick)), border-color var(--swui-animation, var(--swui-motion-quick)), opacity var(--swui-animation, var(--swui-motion-quick)), transform var(--swui-animation, var(--swui-motion-quick))"
          )
      }
      rule(cls("swui-control-mini")) {
        .minHeight("var(--swui-control-mini-height)")
          .paddingInline(.space(.small))
          .fontSize("12px")
      }
      rule(cls("swui-control-small")) {
        .minHeight("var(--swui-control-small-height)")
          .paddingInline(.space(.medium))
          .fontSize("14px")
      }
      rule(cls("swui-control-regular")) {
        .minHeight("var(--swui-control-regular-height)")
      }
      rule(cls("swui-control-large")) {
        .minHeight("var(--swui-control-large-height)")
          .paddingInline(.space(.xlarge))
          .fontSize("17px")
      }
      rule(cls("swui-control-extraLarge")) {
        .minHeight("var(--swui-control-extra-large-height)")
          .paddingInline(.space(.xlarge))
          .fontSize("19px")
      }
      rule(cls("swui-button-primary")) {
        .color("var(--swui-button-primary-foreground)")
          // Resolve the control tint on the button element itself so the local
          // per-button --swui-control-tint override wins. Falling back to the
          // style-system default avoids depending on an ancestor-resolved token.
          .background("var(--swui-control-tint, var(--swui-button-primary-background))")
      }
      // The bordered (secondary) button surface comes from the shared material.
      // The component emits semantic classes only; this stylesheet feeds the
      // secondary background token in as the material tint so the active
      // StyleSystem owns translucency, blur, rim, and solid fallback.
      rule(cls("swui-button-secondary")) {
        .color("var(--swui-button-secondary-foreground)")
          .custom("--swui-material-tint", "var(--swui-button-secondary-background)")
          .borderColor("var(--swui-button-secondary-border)")
      }
      rule(cls("swui-button-plain")) {
        .color("var(--swui-control-tint, var(--swui-button-plain-foreground))")
          .background("transparent")
          .borderColor("transparent")
          .paddingInline(.zero)
      }
      // Glass buttons take their fill from the shared `swui-glass` recipe, so
      // these rules only set semantic text/border behavior. The plain glass
      // keeps the neutral surface tint; the prominent glass is washed with the
      // control tint.
      rule(cls("swui-button-glass")) {
        .color("var(--swui-text)")
          .borderColor("transparent")
      }
      rule(cls("swui-button-glass-prominent")) {
        .color("var(--swui-accent-text)")
          .borderColor("transparent")
          .custom("--swui-material-tint", "var(--swui-control-tint, var(--swui-accent))")
      }
      // Shift the material tint on hover (rather than painting an opaque
      // background over the glass) so the frosted surface is preserved.
      rule(cls("swui-button-secondary").pseudo(.hover)) {
        .custom("--swui-material-tint", "var(--swui-button-secondary-hover-background)")
      }
      // Press feedback is part of a button's own interaction (its responsibility,
      // not the caller's): every enabled button dips slightly when pressed,
      // eased by the transform transition above.
      rule(cls("swui-button").not(.pseudo(.disabled)).not(cls("swui-control-disabled")).pseudo(.active)) {
        .transform("scale(0.97)")
      }
      rule(list(
        cls("swui-control-disabled"),
        cls("swui-button").pseudo(.disabled),
        cls("swui-text-field").pseudo(.disabled),
        cls("swui-picker").pseudo(.disabled)
      )) {
        .cursor("default")
          .opacity("var(--swui-control-disabled-opacity)")
      }
      rule(cls("swui-modifier")) {
        .boxSizing("border-box")
      }
      rule(cls("swui-box-modifier")) {
        .display("block")
      }
      rule(list(cls("swui-text-style-modifier"), cls("swui-semantic-modifier"))) {
        .display("contents")
      }
      rule(cls("swui-text-style-modifier").descendant(cls("swui-text"))) {
        .fontFamily("inherit")
          .fontSize("inherit")
          .fontStyle("inherit")
          .fontWeight("inherit")
          .textAlign("inherit")
          .textDecoration("inherit")
      }
      rule(cls("swui-style-foreground").descendant(cls("swui-text"))) {
        .color("inherit")
      }
      rule(cls("swui-label")) {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.small))
      }
      rule(cls("swui-label-icon")) {
        .display("inline-flex")
          .alignItems("center")
          .color("currentColor")
      }
      rule(cls("swui-label-title")) {
        .display("inline")
      }
      // The badge fill comes from the shared material (Badge composes
      // `.thinMaterial`); this rule keeps the badge's own border, radius,
      // padding, and text color.
      rule(cls("swui-badge")) {
        .display("inline-flex")
          .alignItems("center")
          .width("fit-content")
          .borderRadius("var(--swui-badge-radius)")
          .padding(.badgePadding)
          .border("var(--swui-badge-border)")
          .color("var(--swui-badge-foreground)")
          .fontSize("12px")
          .lineHeight("1.4")
      }
      rule(cls("swui-form")) {
        .margin("0")
          .width("fit-content")
          .maxWidth("100%")
      }
      rule(cls("swui-button-action-form")) {
        .display("inline-flex")
      }
      // SwiftUI links are accent-tinted by default and not underlined. Default to
      // the accent (so a bare Link is a visible link) and drop the user-agent
      // underline; inside a foregroundStyle scope the link inherits that color
      // instead, mirroring `.swui-style-foreground .swui-text`.
      rule(cls("swui-link")) {
        .color("var(--swui-accent)")
          .textDecoration("none")
      }
      rule(cls("swui-style-foreground").descendant(cls("swui-link"))) {
        .color("inherit")
      }
      rule(cls("swui-navigation-stack")) {
        .display("grid")
          .gap(.navigationGap)
          .boxSizing("border-box")
          .width("fit-content")
          .maxWidth("100%")
      }
      rule(cls("swui-navigation-link")) {
        .color("var(--swui-navigation-link-foreground)")
          .textDecoration("var(--swui-navigation-link-decoration)")
      }
      rule(cls("swui-navigation-link").pseudo(.hover)) {
        .textDecoration("var(--swui-navigation-link-hover-decoration)")
      }
      rule(cls("swui-scroll-view")) {
        .boxSizing("border-box")
          .maxWidth("100%")
          .maxHeight("100%")
          .overscrollBehavior("contain")
      }
      rule(cls("swui-scroll-view-hidden-indicators")) {
        .scrollbarWidth("none")
      }
      rule(cls("swui-scroll-view-hidden-indicators").pseudoElement(.webkitScrollbar)) {
        .display("none")
      }
      rule(cls("swui-divider")) {
        .background("var(--swui-border)")
          .flex("0 0 auto")
          .width("100%")
          .height("1px")
      }
      rule(list(
        cls("swui-hstack").child(cls("swui-divider")),
        cls("swui-lazy-hstack").child(cls("swui-divider")),
        cls("swui-toolbar").child(cls("swui-divider"))
      )) {
        .width("1px")
          .height("auto")
          .alignSelf("stretch")
      }
      rule(cls("swui-section")) {
        .display("grid")
          .gap(.space(.medium))
          .boxSizing("border-box")
      }
      rule(cls("swui-section-footer")) {
        .fontSize("13px")
          .color("var(--swui-text-muted)")
      }
      rule(cls("swui-list")) {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(cls("swui-list-row")) {
        .display("flex")
          .alignItems("center")
          .gap(.space(.small))
          .boxSizing("border-box")
      }
      rule(cls("swui-list-row").descendant(cls("swui-text"))) {
        .lineHeight("1.35")
      }
      rule(cls("swui-list-row").child(cls("swui-text").pseudo(.firstChild))) {
        .fontWeight("500")
      }
      // Secondary text in a row (anything after the leading title) reads smaller.
      // Keyed to structural position rather than colour, so muting (handled by
      // `.foregroundStyle(.secondary)`) and sizing stay independent concerns.
      rule(cls("swui-list-row").child(cls("swui-text").not(.pseudo(.firstChild)))) {
        .fontSize("13px")
      }
      rule(cls("swui-field")) {
        .display("grid")
          .gap(.space(.xsmall))
          .color("var(--swui-text)")
      }
      rule(cls("swui-picker-field")) {
        .display("grid")
          .gap(.space(.xsmall))
      }
      rule(list(cls("swui-field-label"), cls("swui-toggle-label"))) {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // The field fill comes from the shared material (TextField/Picker/
      // DatePicker compose `.thinMaterial`); this rule keeps the field's
      // border, radius, padding, and text color. `<input>`/`<select>` are
      // replaced elements, so the material's `::before` rim/refraction
      // overlay does not paint, but its fill and backdrop blur still apply.
      rule(list(cls("swui-text-field"), cls("swui-picker"), cls("swui-date-picker"))) {
        .minHeight("var(--swui-control-regular-height)")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-field-radius)")
          .padding(.fieldPadding)
          .boxSizing("border-box")
          .color("var(--swui-text)")
          .font("inherit")
      }
      // Slider: a transparent native range input layered over a custom track,
      // fill, and Liquid Glass thumb. `--swui-slider-progress` (0..1, seeded
      // server-side and updated by the client on input) positions the fill and
      // thumb. The thumb is a real `.swui-glass` element so the refraction
      // script lenses the track and page beneath it as it slides.
      rule(cls("swui-slider")) {
        .position("relative")
          .display("flex")
          .alignItems("center")
          .minWidth("160px")
          .minHeight("var(--swui-slider-thumb-size)")
          .boxSizing("border-box")
          .cursor("pointer")
          .accentColor("var(--swui-control-tint, var(--swui-accent))")
          .custom("--swui-slider-track-height", "5px")
          .custom("--swui-slider-thumb-size", "20px")
      }
      rule(cls("swui-slider-track")) {
        .position("relative")
          .flexGrow("1")
          .height("var(--swui-slider-track-height)")
          .borderRadius("999px")
          .background("color-mix(in srgb, var(--swui-text-muted) 38%, transparent)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(cls("swui-slider-fill")) {
        .position("absolute")
          .top(.zero)
          .left("0")
          .height("100%")
          .borderRadius("999px")
          .background("var(--swui-control-tint, var(--swui-accent))")
          .width("calc(var(--swui-slider-progress) * (100% - var(--swui-slider-thumb-size)) + var(--swui-slider-thumb-size) / 2)")
      }
      // Transparent native input on top owns drag, keyboard, step, and focus.
      rule(cls("swui-slider-input")) {
        .position("absolute")
          .top(.zero)
          .left("0")
          .width("100%")
          .height("100%")
          .margin("0")
          .padding(.zero)
          .opacity("0")
          .cursor("pointer")
          .zIndex("2")
          .background("transparent")
          .custom("touch-action", "none")
          .custom("-webkit-appearance", "none")
          .custom("appearance", "none")
      }
      // The native thumb stays invisible but is sized to match the visible Liquid
      // Glass thumb, so the browser's value<->position mapping uses the same
      // inset as the custom thumb. That keeps the visible thumb exactly under the
      // cursor while the native input keeps owning the value (its trusted
      // input/change events commit the binding).
      rule(cls("swui-slider-input").pseudoElement(.webkitSliderThumb)) {
        .custom("-webkit-appearance", "none")
          .custom("appearance", "none")
          .width("var(--swui-slider-thumb-size)")
          .height("var(--swui-slider-thumb-size)")
          .opacity("0")
          .border("none")
      }
      rule(cls("swui-slider-input").pseudoElement(.mozRangeThumb)) {
        .width("var(--swui-slider-thumb-size)")
          .height("var(--swui-slider-thumb-size)")
          .opacity("0")
          .border("none")
      }
      rule(cls("swui-slider-input").pseudo(.disabled)) {
        .cursor("default")
      }
      // Descendant selector outranks the single-class `.swui-glass` recipe so the
      // knob keeps its geometry and crisp white body while the refraction script
      // supplies the lensing backdrop-filter. The body stays mostly opaque (only
      // the very rim is translucent) so the knob reads as a clean control rather
      // than a large see-through disc; the glass shows as a faint edge.
      rule(cls("swui-slider").descendant(cls("swui-slider-thumb"))) {
        .position("absolute")
          .top(.percent(50))
          .left("calc(var(--swui-slider-progress) * (100% - var(--swui-slider-thumb-size)))")
          .width("var(--swui-slider-thumb-size)")
          .height("var(--swui-slider-thumb-size)")
          .transform("translateY(-50%)")
          .borderRadius("999px")
          .background("radial-gradient(circle, #ffffff 0%, #ffffff 60%, rgba(255, 255, 255, 0.85) 100%)")
          .boxShadow("0 1px 3px rgba(0, 0, 0, 0.28), 0 0 0 0.5px rgba(0, 0, 0, 0.04)")
          .pointerEvents("none")
          .zIndex("1")
          .custom("--swui-glass-bezel", "4")
          .custom("--swui-glass-scale", "6")
      }
      rule(cls("swui-slider-input").pseudo(.focusVisible).generalSibling(cls("swui-slider-thumb"))) {
        .boxShadow("0 1px 3px rgba(0, 0, 0, 0.28), 0 0 0 0.5px rgba(0, 0, 0, 0.04), 0 0 0 3px color-mix(in srgb, var(--swui-accent) 45%, transparent)")
      }
      rule(cls("swui-toggle")) {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.small))
          .color("var(--swui-text)")
          .cursor("pointer")
      }
      rule(cls("swui-toggle-input")) {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
      }
      // The off-state track fill comes from the shared material (Toggle
      // composes `.thinMaterial`); this rule keeps the track's size,
      // pill radius, and border. The checked rules below paint the track
      // solid accent, and the thumb lives on the track's own `::after`.
      rule(cls("swui-toggle-control")) {
        .width("var(--swui-toggle-width)")
          .height("var(--swui-toggle-height)")
          .borderRadius("var(--swui-radius-pill)")
          .border("1px solid var(--swui-border)")
          .boxSizing("border-box")
          .position("relative")
      }
      // The thumb is the sliding Liquid Glass knob. This descendant selector
      // outranks the shared single-class `.swui-glass` recipe, so the knob
      // keeps its size, circular radius, translucent body, and float shadow
      // while the per-element refraction script lenses the track and backdrop
      // through its rim. The bezel/scale custom properties down-tune the
      // script for this small surface so the rim band and displacement stay
      // proportional instead of using the panel-scale defaults.
      rule(cls("swui-toggle-control").descendant(cls("swui-toggle-thumb"))) {
        .position("absolute")
          .width("var(--swui-toggle-thumb-size)")
          .height("var(--swui-toggle-thumb-size)")
          .left("var(--swui-toggle-thumb-offset)")
          .top(.toggleThumbOffset)
          .borderRadius("999px")
          // Opaque white core, translucent rim: the rim coincides with the
          // refraction bezel, so the lensed track and specular highlight read
          // at the edge while the centre stays a solid knob.
          .background("radial-gradient(circle, rgba(255, 255, 255, 0.98) 0%, rgba(255, 255, 255, 0.96) 46%, rgba(255, 255, 255, 0.42) 100%)")
          .boxShadow("0 2px 5px rgba(0, 0, 0, 0.3), inset 0 1px 1px rgba(255, 255, 255, 0.9)")
          .transition("transform var(--swui-animation, var(--swui-motion-quick))")
          .custom("--swui-glass-bezel", "5")
          .custom("--swui-glass-scale", "7")
      }
      rule(cls("swui-toggle-input").pseudo(.checked).adjacentSibling(cls("swui-toggle-control"))) {
        .background("var(--swui-accent)")
          .borderColor("var(--swui-accent)")
      }
      rule(cls("swui-toggle-input").pseudo(.checked).adjacentSibling(cls("swui-toggle-control")).descendant(cls("swui-toggle-thumb"))) {
        .transform("translateX(var(--swui-toggle-checked-thumb-offset))")
      }
      rule(cls("swui-image")) {
        .maxWidth("100%")
          .height("auto")
          .display("inline-block")
      }
      // An SVG symbol scales with the surrounding text (slightly larger, like an
      // SF Symbol) and inherits its color via fill="currentColor".
      rule(cls("swui-symbol")) {
        .width("1.15em")
          .height("1.15em")
          .verticalAlign("-0.15em")
          .flexShrink("0")
      }
      // The text fallback for an unknown identifier keeps the monospace label.
      rule(cls("swui-symbol-text")) {
        .width("auto")
          .height("auto")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.85em")
          .lineHeight("1")
          .verticalAlign("baseline")
      }

      // MARK: ProgressView
      // Container stacks an optional label over the bar/spinner.
      rule(cls("swui-progress")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
          .boxSizing("border-box")
      }
      rule(cls("swui-progress-label")) {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // The track fill comes from the composed `.ultraThinMaterial`; the
      // value paints solid accent. `<progress>` is a replaced element, so
      // its `::before` overlay does not render and only the fill/blur apply.
      rule(cls("swui-progress-bar")) {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("100%")
          .height("6px")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(cls("swui-progress-bar").pseudoElement(.webkitProgressBar)) {
        .background("transparent")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-progress-bar").pseudoElement(.webkitProgressValue)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-progress-bar").pseudoElement(.mozProgressBar)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      // Indeterminate spinner; `@keyframes swui-spin` lives in the typed
      // at-rule layer below.
      rule(cls("swui-progress-spinner")) {
        .width("20px")
          .height("20px")
          .borderRadius("999px")
          .border("2px solid color-mix(in srgb, var(--swui-text-muted) 30%, transparent)")
          .borderTopColor("var(--swui-control-tint, var(--swui-accent))")
          .animation("swui-spin 0.7s linear infinite")
          .boxSizing("border-box")
      }

      // MARK: Gauge
      rule(cls("swui-gauge")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
          .boxSizing("border-box")
      }
      rule(cls("swui-gauge-label")) {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // `<meter>` track fill comes from the composed `.ultraThinMaterial`;
      // the value paints solid accent. Like `<progress>` it is replaced, so
      // only the fill/blur apply and the rim overlay does not render.
      rule(cls("swui-gauge-meter")) {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("100%")
          .height("8px")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(cls("swui-gauge-meter").pseudoElement(.webkitMeterBar)) {
        .background("transparent")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-gauge-meter").pseudoElement(.webkitMeterOptimumValue)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-gauge-meter").pseudoElement(.webkitMeterSuboptimumValue)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-gauge-meter").pseudoElement(.webkitMeterEvenLessGoodValue)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(cls("swui-gauge-meter").pseudoElement(.mozMeterBar)) {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }

      // MARK: DisclosureGroup
      // `<details>` is not replaced, so the composed `.regularMaterial`
      // paints its full recipe (fill + rim + refraction) on the container.
      rule(cls("swui-disclosure-group")) {
        .borderRadius("var(--swui-container-radius)")
          .border("var(--swui-container-border)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(cls("swui-disclosure-summary")) {
        .display("flex")
          .alignItems("center")
          .gap(.space(.small))
          .padding(.space(.medium))
          .cursor("pointer")
          .fontWeight("600")
          .color("var(--swui-text)")
          .userSelect("none")
          .listStyle("none")
      }
      rule(cls("swui-disclosure-summary").pseudoElement(.webkitDetailsMarker)) {
        .display("none")
      }
      rule(cls("swui-disclosure-content")) {
        .padding(.zero, .space(.medium), .space(.medium), .space(.medium))
          .color("var(--swui-text)")
      }

      // MARK: TextEditor
      // `<textarea>` is a form control: the composed `.thinMaterial` fill
      // and backdrop blur apply, while the rim overlay does not render.
      rule(cls("swui-text-editor")) {
        .minHeight("calc(var(--swui-control-regular-height) * 3)")
          .width("100%")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-field-radius)")
          .padding(.fieldPadding)
          .boxSizing("border-box")
          .color("var(--swui-text)")
          .font("inherit")
          .resize("vertical")
      }

      // MARK: ColorPicker
      // Label and swatch sit in a row; this overrides the `.swui-field`
      // grid set earlier in source order.
      rule(cls("swui-color-picker")) {
        .display("flex")
          .flexDirection("row")
          .alignItems("center")
          .justifyContent("space-between")
          .gap(.space(.small))
          .cursor("pointer")
      }
      // No material on the swatch — it must show the chosen color verbatim.
      rule(cls("swui-color-picker-input")) {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("44px")
          .height("28px")
          .padding(.zero)
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-radius-small)")
          .background("transparent")
          .cursor("pointer")
          .boxSizing("border-box")
      }
      rule(cls("swui-color-picker-input").pseudoElement(.webkitColorSwatchWrapper)) {
        .padding(.zero)
      }
      rule(cls("swui-color-picker-input").pseudoElement(.webkitColorSwatch)) {
        .border("none")
          .borderRadius("calc(var(--swui-radius-small) - 1px)")
      }
      rule(cls("swui-color-picker-input").pseudoElement(.mozColorSwatch)) {
        .border("none")
          .borderRadius("calc(var(--swui-radius-small) - 1px)")
      }

      // MARK: Picker — segmented / inline
      // The `.segmented` style composes the `bar` material as a pill track;
      // each option is a hidden radio whose label span is the visual
      // segment, highlighted via the same `input:checked ~ label` sibling
      // pattern the toggle uses (no `:has()` dependency). The `.inline`
      // style is a plain vertical radio list with a leading marker.
      rule(cls("swui-picker-segmented")) {
        .display("inline-flex")
          .flexDirection("row")
          .alignItems("stretch")
          .gap(.px(2))
          .padding(.px(2))
          .minHeight("var(--swui-control-regular-height)")
          .borderRadius("var(--swui-button-radius)")
          .boxSizing("border-box")
          .overflow("hidden")
      }
      rule(cls("swui-picker-inline")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
      }
      rule(cls("swui-picker-segment")) {
        .position("relative")
          .display("inline-flex")
          .cursor("pointer")
          .color("var(--swui-text)")
      }
      rule(cls("swui-picker-segmented").descendant(cls("swui-picker-segment"))) {
        .flex("1 0 auto")
          .minWidth("max-content")
      }
      rule(cls("swui-picker-segment-input")) {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
          .width("0")
          .height("0")
      }
      rule(cls("swui-picker-segment-label")) {
        .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .width("100%")
          .boxSizing("border-box")
          .userSelect("none")
          .fontSize("var(--swui-field-label-size)")
      }
      rule(cls("swui-picker-segmented").descendant(cls("swui-picker-segment-label"))) {
        .minHeight("calc(var(--swui-control-regular-height) - 6px)")
          .padding(.px(6), .px(14))
          .borderRadius("calc(var(--swui-button-radius) - 2px)")
          .textAlign("center")
          .lineHeight("1")
          .whiteSpace("nowrap")
          .transition("background var(--swui-animation, var(--swui-motion-quick)), color var(--swui-animation, var(--swui-motion-quick))")
      }
      rule(
        cls("swui-picker-segmented")
          .descendant(cls("swui-picker-segment-input").pseudo(.checked))
          .generalSibling(cls("swui-picker-segment-label"))
      ) {
        .background("var(--swui-accent)")
          .color("var(--swui-accent-text)")
      }
      rule(cls("swui-picker-inline").descendant(cls("swui-picker-segment-label"))) {
        .justifyContent("flex-start")
          .gap(.space(.small))
          .padding(.space(.xsmall), .zero)
      }
      rule(cls("swui-picker-inline").descendant(cls("swui-picker-segment-label").pseudoElement(.before))) {
        .content("\"\"")
          .width("18px")
          .height("18px")
          .borderRadius("999px")
          .border("2px solid var(--swui-border)")
          .boxSizing("border-box")
          .flex("0 0 auto")
      }
      rule(
        cls("swui-picker-inline")
          .descendant(cls("swui-picker-segment-input").pseudo(.checked))
          .generalSibling(cls("swui-picker-segment-label").pseudoElement(.before))
      ) {
        .borderColor("var(--swui-accent)")
          .background(
            "radial-gradient(circle at center, var(--swui-accent) 0 5px, transparent 6px)")
      }
      rule(cls("swui-picker-segment-input").pseudo(.focusVisible).generalSibling(cls("swui-picker-segment-label"))) {
        .outline("2px solid var(--swui-accent)")
          .outlineOffset("2px")
      }

      // MARK: Menu
      // `<details>` anchors a floating panel under an interactive-glass
      // summary. The native disclosure triangle is hidden; the panel
      // composes `regularMaterial` plus the container elevation shadow.
      rule(cls("swui-menu")) {
        .position("relative")
          .display("inline-block")
      }
      rule(cls("swui-menu-label")) {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.xsmall))
          .padding(.fieldPadding)
          .borderRadius("var(--swui-radius-pill)")
          .cursor("pointer")
          .userSelect("none")
          .listStyle("none")
          .color("var(--swui-text)")
      }
      rule(cls("swui-menu-label").pseudoElement(.webkitDetailsMarker)) {
        .display("none")
      }
      rule(cls("swui-menu-content")) {
        .position("absolute")
          .top(.menuOffset(.xsmall))
          .insetInlineStart("0")
          .minWidth("180px")
          .display("flex")
          .flexDirection("column")
          .gap(.px(2))
          .padding(.space(.xsmall))
          .borderRadius("var(--swui-radius-medium)")
          .boxShadow("var(--swui-container-shadow)")
          .zIndex("40")
          .boxSizing("border-box")
      }

      // MARK: TabView
      // Each `Tab` is a `display: contents` unit holding a hidden radio
      // (the tab button) and its panel. Flattening the unit lets every tab
      // button form the bar (order 0) while the active panel sits below it
      // (order 1, full width). The active panel is revealed purely in CSS
      // via `:has(.swui-tab-input:checked)`, with no client runtime; the
      // adjacency stays scoped to one unit, so no panel leaks across tabs.
      rule(cls("swui-tabview")) {
        .display("flex")
          .flexWrap("wrap")
          .alignItems("center")
          .gap(.space(.xsmall))
      }
      rule(cls("swui-tab")) {
        .display("contents")
      }
      rule(cls("swui-tab-input")) {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
          .width("0")
          .height("0")
      }
      rule(cls("swui-tab-item")) {
        .order("0")
          .display("inline-flex")
          .alignItems("center")
          .gap(.space(.xsmall))
          .padding(.fieldPadding)
          .borderRadius("var(--swui-radius-pill)")
          .cursor("pointer")
          .userSelect("none")
          .color("var(--swui-text)")
          .transition("background var(--swui-animation, var(--swui-motion-quick)), color var(--swui-animation, var(--swui-motion-quick))")
      }
      rule(cls("swui-tab-item").has(cls("swui-tab-input").pseudo(.checked))) {
        .background("var(--swui-accent)")
          .color("var(--swui-accent-text)")
      }
      rule(cls("swui-tab-item").has(cls("swui-tab-input").pseudo(.focusVisible))) {
        .outline("2px solid var(--swui-accent)")
          .outlineOffset("2px")
      }
      rule(cls("swui-tab-panel")) {
        .order("1")
          .flexBasis("100%")
          .width("100%")
          .display("none")
          .paddingBlockStart(.space(.small))
      }
      rule(cls("swui-tab-item").has(cls("swui-tab-input").pseudo(.checked)).adjacentSibling(cls("swui-tab-panel"))) {
        .display("block")
      }

      // MARK: Searchable
      // The search field stacks above the searchable content. It composes
      // the shared thin material for its fill and backdrop blur; the rule
      // keeps its border, radius, padding, and text color.
      rule(cls("swui-searchable")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(cls("swui-search-bar")) {
        .display("flex")
      }
      rule(cls("swui-search-field")) {
        .custom("--swui-material-tint", "var(--swui-field-background)")
          .width("100%")
          .boxSizing("border-box")
          .minHeight("var(--swui-control-regular-height)")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-radius-pill)")
          .padding(.fieldPadding)
          .color("var(--swui-text)")
          .font("inherit")
      }
      rule(list(cls("swui-search-suggestion-host"), cls("swui-search-scoped"))) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(cls("swui-search-suggestions")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
      }
      rule(cls("swui-search-tokenized")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(cls("swui-search-tokens")) {
        .display("flex")
          .gap(.space(.xsmall))
          .flexWrap("wrap")
      }
      rule(cls("swui-search-token")) {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.xsmall))
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-radius-pill)")
          .background("var(--swui-surface-raised)")
          .color("var(--swui-text)")
          .padding(.px(2), .space(.small))
          .font("inherit")
          .lineHeight("1")
          .cursor("pointer")
      }
      rule(cls("swui-search-scopes")) {
        .display("flex")
          .gap(.space(.xsmall))
          .flexWrap("wrap")
      }
      rule(cls("swui-search-scope")) {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.xsmall))
      }
      // MARK: Presentation (alert / confirmationDialog / sheet / popover)
      // The shared `<dialog>` overlay composes the material primitive; this
      // rule keeps the border, radius, drop shadow, sizing, and modal layout.
      // A `<dialog>` without `open` is `display: none` by UA default, so the
      // overlay costs no layout while hidden.
      rule(cls("swui-presentation")) {
        .margin("auto")
          .padding(.zero)
          .boxSizing("border-box")
          .width("100%")
          .maxWidth("min(92vw, 28rem)")
          .border("var(--swui-container-border)")
          .borderRadius("var(--swui-container-radius)")
          .boxShadow("var(--swui-container-shadow)")
          .color("var(--swui-text)")
      }
      // Pin the open overlay to the viewport center. This holds for the
      // true top-layer modal (runtime `showModal()`) and for the in-flow
      // `<dialog open>` degradation when the client runtime is absent.
      rule(cls("swui-presentation").attribute("open")) {
        .position("fixed")
          .top(.zero)
          .right("0")
          .bottom("0")
          .left("0")
      }
      // The scrim only paints for a true modal (top layer). Without the
      // runtime the dialog is in-flow and the page behind stays visible —
      // an explicit, documented degradation, not a silent fallback.
      rule(cls("swui-presentation").pseudoElement(.backdrop)) {
        .background("color-mix(in srgb, var(--swui-text) 32%, transparent)")
          .custom("-webkit-backdrop-filter", "blur(2px)")
          .backdropFilter("blur(2px)")
      }
      rule(cls("swui-presentation-surface")) {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.medium))
          .padding(.space(.large))
          .boxSizing("border-box")
      }
      rule(cls("swui-presentation-title")) {
        .margin("0")
          .fontSize("var(--swui-heading-subsection-size)")
          .lineHeight("1.25")
          .color("var(--swui-text)")
      }
      rule(cls("swui-presentation-message")) {
        .margin("0")
          .color("var(--swui-text-muted)")
      }
      rule(cls("swui-presentation-actions")) {
        .display("flex")
          .flexWrap("wrap")
          .gap(.space(.small))
          .justifyContent("flex-end")
      }
      // Action sheets stack their choices full width, matching the native
      // confirmation dialog layout.
      rule(cls("swui-presentation-confirmation").descendant(cls("swui-presentation-actions"))) {
        .flexDirection("column")
          .alignItems("stretch")
      }
      // The sheet anchors to the bottom edge and squares its lower corners.
      rule(cls("swui-presentation-sheet")) {
        .margin("auto auto 0 auto")
          .maxWidth("min(96vw, 40rem)")
          .borderBottomLeftRadius("0")
          .borderBottomRightRadius("0")
      }
      rule(cls("swui-presentation-sheet").attribute("open")) {
        .top(.auto)
      }
      // The popover reads as a compact panel. True source anchoring needs the
      // CSS anchor positioning API; until then it presents centered.
      rule(cls("swui-presentation-popover")) {
        .maxWidth("min(92vw, 20rem)")
      }
      rule(cls("swui-grid-row").child(.universal)) {
        .textAlign("var(--swui-grid-cell-horizontal-alignment)")
      }
      // Native form controls inherit the page font.
      rule(list(el(.input), el(.button), el(.select), el(.textarea))) {
        .fontFamily("inherit")
      }
      // Button size variants keep component-specific padding while reading their
      // minimum hit area from the active StyleSystem.
      rule(cls("swui-button").compound(cls("swui-control-mini"))) {
        .minHeight("var(--swui-control-mini-height)")
          .padding(.px(4), .px(9))
          .borderRadius("var(--swui-radius-small)")
          .fontSize("11px")
      }
      rule(cls("swui-button").compound(cls("swui-control-small"))) {
        .minHeight("var(--swui-control-small-height)")
          .padding(.px(5), .px(11))
          .fontSize("12px")
      }
      rule(cls("swui-button").compound(cls("swui-control-regular"))) {
        .minHeight("var(--swui-control-regular-height)")
          .padding(.px(7), .px(14))
          .fontSize("14px")
      }
      rule(cls("swui-button").compound(cls("swui-control-large"))) {
        .minHeight("var(--swui-control-large-height)")
          .padding(.px(10), .px(20))
          .fontSize("16px")
      }
      rule(cls("swui-list-row").pseudo(.lastChild)) {
        .borderBottom("0")
      }
      rule(cls("swui-section-header")) {
        .margin("0")
          .padding(.px(10), .px(14), .px(6), .px(14))
          .background("color-mix(in srgb, var(--swui-text-muted) 7%, transparent)")
          .color("var(--swui-text-muted)")
          .fontSize("11.5px")
          .fontWeight("700")
          .letterSpacing("0.05em")
          .textTransform("uppercase")
      }
      rule(list(cls("swui-text-field").pseudo(.focus), cls("swui-text-editor").pseudo(.focus))) {
        .borderColor("var(--swui-accent)")
      }
      rule(cls("swui-stepper")) {
        .display("inline-flex")
          .alignItems("center")
          .width("fit-content")
          .maxWidth("100%")
          .minHeight("0")
          .padding(.zero)
          .overflow("hidden")
          .background("var(--swui-surface-raised)")
          .border("1px solid var(--swui-border)")
          .borderRadius("var(--swui-button-radius)")
          .color("var(--swui-text)")
          .boxSizing("border-box")
      }
      rule(cls("swui-stepper-button")) {
        .display("inline-flex")
          .alignItems("center")
          .justifyContent("center")
          .width("32px")
          .height("31px")
          .minHeight("0")
          .padding(.zero)
          .border("0")
          .background("transparent")
          .color("var(--swui-control-tint, var(--swui-accent))")
          .font("inherit")
          .fontSize("16px")
          .fontWeight("500")
          .lineHeight("1")
          .cursor("pointer")
      }
      rule(list(
        cls("swui-stepper-value"),
        cls("swui-stepper").descendant(cls("val"))
      )) {
        .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .minWidth("42px")
          .height("31px")
          .borderLeft("1px solid var(--swui-border)")
          .borderRight("1px solid var(--swui-border)")
          .color("var(--swui-text)")
          .fontVariantNumeric("tabular-nums")
          .textAlign("center")
      }
    }
  }
  // MARK: Liquid Glass material primitive

  private static var utilityStylesheet: Stylesheet {
    Stylesheet {
      paddingUtilityRules
      for utility in StyleSystemUtility.defaults {
        rule(utility.className, utility.style)
      }
      rule(.swuiGapStack) {
        .gap("var(--swui-stack-spacing)")
      }
      rule(.swuiGapNone) {
        .gap("0")
      }
      rule(.swuiGapExtraSmall) {
        .gap(.space(.xsmall))
      }
      rule(.swuiGapSmall) {
        .gap(.space(.small))
      }
      rule(.swuiGapMedium) {
        .gap(.space(.medium))
      }
      rule(.swuiGapLarge) {
        .gap(.space(.large))
      }
      rule(.swuiGapExtraLarge) {
        .gap(.space(.xlarge))
      }
      rule(.swuiAlignItemsLeading) {
        .alignItems("flex-start")
      }
      rule(.swuiAlignItemsTop) {
        .alignItems("flex-start")
      }
      rule(.swuiAlignItemsCenter) {
        .alignItems("center")
      }
      rule(.swuiAlignItemsTrailing) {
        .alignItems("flex-end")
      }
      rule(.swuiAlignItemsBottom) {
        .alignItems("flex-end")
      }
      rule(.swuiAlignItemsStretch) {
        .alignItems("stretch")
      }
      rule(.swuiJustifyItemsLeading) {
        .justifyItems("flex-start")
      }
      rule(.swuiJustifyItemsCenter) {
        .justifyItems("center")
      }
      rule(.swuiJustifyItemsTrailing) {
        .justifyItems("flex-end")
      }
      rule(.swuiJustifyItemsStretch) {
        .justifyItems("stretch")
      }
    }
  }

  /// The single Liquid Glass recipe every chrome surface composes. A surface
  /// adds `.swui-material`/`.swui-glass` plus one level modifier; the level
  /// only scales the fill opacity, while blur, saturation, rim, and refraction
  /// come from the active design style's tokens. Solid styles set those tokens
  /// to no-op values, so the same markup reads as a plain surface.
  private static var paddingUtilityRules: Stylesheet {
    Stylesheet {
      for space in Space.allCases {
        for axis in PaddingClassAxis.allCases {
          rule(space.paddingClassName(axis), axis.style(value: space.rawValue))
        }
      }
    }
  }

  private static var materialStylesheet: Stylesheet {
    Stylesheet {
      // Base fill + backdrop. `isolation: isolate` establishes a stacking
      // context so the `::before` overlay paints above the fill but below
      // the element content (z-index: -1). The interactive multiplier folds
      // into the backdrop brightness and defaults to 1.
      // Shared base: a translucent fill and its own stacking context. The glass
      // blur is a fraction of the material blur so refraction can show through.
      rule(list(cls("swui-material"), cls("swui-glass"))) {
        .position("relative")
          .isolation("isolate")
          .custom("--swui-material-level-opacity", "var(--swui-material-opacity)")
          .custom("--swui-glass-blur", "calc(var(--swui-material-blur) * 0.06)")
          .background(
            "color-mix(in srgb, var(--swui-material-tint) calc(var(--swui-material-level-opacity) * 100%), transparent)"
          )
      }
      // Material is frosted vibrancy: a wide Gaussian blur that *scatters* and
      // obscures the backdrop (SwiftUI `.regularMaterial` etc.). No refraction,
      // no specular — a flat translucent layer for backgrounds.
      rule(cls("swui-material")) {
        .backdropFilter(
          "blur(var(--swui-material-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
        )
          .custom(
            "-webkit-backdrop-filter",
            "blur(var(--swui-material-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
          )
      }
      // Liquid Glass is refractive: a *light* tint (so the refracted backdrop
      // reads, not a frosted panel) and a faint backdrop blur, while the
      // per-element client script sets the `backdrop-filter` that lenses the
      // backdrop at the rim and adds the specular highlight (SwiftUI `Glass` /
      // `glassEffect`). The only chrome is a soft drop shadow that floats the
      // control off the backdrop (liquid-dom's default optical model).
      rule(cls("swui-glass")) {
        .background(
          "color-mix(in srgb, var(--swui-material-tint) calc(var(--swui-material-level-opacity) * 16%), transparent)"
        )
          .backdropFilter(
            "blur(var(--swui-glass-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
          )
          .custom(
            "-webkit-backdrop-filter",
            "blur(var(--swui-glass-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
          )
          .boxShadow("0 10px 24px -6px rgba(15, 23, 42, 0.18)")
      }
      // Level modifiers scale the regular-level opacity by ±N steps. Solid
      // styles use a zero step, collapsing every level onto one fill.
      rule(cls("swui-material-ultra-thin")) {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) - 2 * var(--swui-material-opacity-step))")
      }
      rule(cls("swui-material-thin")) {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) - 1 * var(--swui-material-opacity-step))")
      }
      rule(cls("swui-material-regular")) {
        .custom("--swui-material-level-opacity", "var(--swui-material-opacity)")
      }
      rule(cls("swui-material-thick")) {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 1 * var(--swui-material-opacity-step))")
      }
      rule(cls("swui-material-ultra-thick")) {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 2 * var(--swui-material-opacity-step))")
      }
      // The bar material (toolbars/tab bars) sits one step more frosted
      // than regular so chrome reads as a distinct layer over content.
      rule(cls("swui-material-bar")) {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 1 * var(--swui-material-opacity-step))")
      }
      // Interactive glass: pointer hover/press scales the backdrop
      // brightness through the multiplier the base recipe folds in.
      rule(cls("swui-glass-interactive")) {
        .cursor("pointer")
      }
      rule(cls("swui-glass-interactive").pseudo(.hover)) {
        .custom("--swui-material-interactive", "1.12")
      }
      rule(cls("swui-glass-interactive").pseudo(.active)) {
        .custom("--swui-material-interactive", "0.94")
      }
      // Shared compositing context for grouped glass surfaces.
      rule(cls("swui-glass-container")) {
        .display("flex")
          .isolation("isolate")
      }
    }
  }

  /// At-rules (`@supports`/`@media`/`@keyframes`) modeled as typed stylesheet
  /// items rather than raw CSS strings, so the whole stylesheet is the typed
  /// single source of truth.
  private static var atRulesStylesheet: Stylesheet {
    Stylesheet {
      // Opaque material fallback where translucency is unavailable or unwanted:
      // both paths drop to the solid fill and hide the overlay.
      supports(.not(.backdropFilterBlurAvailable())) {
        rule(list(cls("swui-material"), cls("swui-glass"))) {
          .background("var(--swui-material-solid-fill)")
        }
        rule(list(
          cls("swui-material").pseudoElement(.before),
          cls("swui-glass").pseudoElement(.before)
        )) {
          .display("none")
        }
      }
      media(.prefersReducedTransparency(.reduce)) {
        rule(list(cls("swui-material"), cls("swui-glass"))) {
          .background("var(--swui-material-solid-fill)")
        }
        rule(list(
          cls("swui-material").pseudoElement(.before),
          cls("swui-glass").pseudoElement(.before)
        )) {
          .display("none")
        }
      }
      // Indeterminate ProgressView spinner.
      keyframes("swui-spin") {
        Keyframe("to") { .transform("rotate(360deg)") }
      }
      // Standard-paced entrance for presented surfaces; gated so motion-sensitive
      // users get the instant present.
      keyframes("swui-present") {
        Keyframe("from") {
          .opacity("0")
            .transform("translateY(8px) scale(0.99)")
        }
        Keyframe("to") {
          .opacity("1")
            .transform("none")
        }
      }
      media(.prefersReducedMotion(.noPreference)) {
        rule(cls("swui-presentation").attribute("open").descendant(cls("swui-presentation-surface"))) {
          .animation("swui-present var(--swui-motion-standard) both")
        }
      }
      // Insertion "from" state for `.transition(_:)`: the freshly-inserted element
      // starts at its enter opacity/transform, then animates to the normal state.
      startingStyle {
        rule(cls("swui-transition")) {
          .opacity("var(--swui-enter-opacity, 1)")
            .transform("var(--swui-enter-transform, none)")
        }
      }
      // Honor reduced-motion globally: collapse all transitions/animations to a
      // near-instant duration (the new `--swui-animation` path included).
      media(.prefersReducedMotion(.reduce)) {
        rule(list(
          .universal,
          StyleSelector.universal.pseudoElement(.before),
          StyleSelector.universal.pseudoElement(.after)
        )) {
          .animationDuration("0.01ms !important")
            .animationIterationCount("1 !important")
            .transitionDuration("0.01ms !important")
        }
      }
    }
  }
}

private extension Length {
  static let zero: Length = .custom("0")
  static let auto: Length = .custom("auto")
  static let pageInlinePadding: Length = .custom("var(--swui-page-inline-padding)")
  static let gridSystemGutter: Length = .custom("var(--swui-grid-system-gutter)")
  static let navigationGap: Length = .custom("var(--swui-navigation-gap)")
  static let badgePadding: Length = .custom("var(--swui-badge-padding)")
  static let fieldPadding: Length = .custom("var(--swui-field-padding)")
  static let toggleThumbOffset: Length = .custom("var(--swui-toggle-thumb-offset)")

  static func space(_ value: Space) -> Length {
    .custom(value.rawValue)
  }

  static func menuOffset(_ spacing: Space) -> Length {
    .custom("calc(100% + \(spacing.rawValue))")
  }
}

private extension Style {
  static func padding(_ value: Length) -> Style {
    .padding(value.cssValue)
  }

  func padding(_ value: Length) -> Style {
    appending(Self.padding(value))
  }

  static func padding(_ vertical: Length, _ horizontal: Length) -> Style {
    .padding("\(vertical.cssValue) \(horizontal.cssValue)")
  }

  func padding(_ vertical: Length, _ horizontal: Length) -> Style {
    appending(Self.padding(vertical, horizontal))
  }

  static func padding(
    _ top: Length,
    _ right: Length,
    _ bottom: Length,
    _ left: Length
  ) -> Style {
    .padding("\(top.cssValue) \(right.cssValue) \(bottom.cssValue) \(left.cssValue)")
  }

  func padding(
    _ top: Length,
    _ right: Length,
    _ bottom: Length,
    _ left: Length
  ) -> Style {
    appending(Self.padding(top, right, bottom, left))
  }

  static func paddingInline(_ value: Length) -> Style {
    .paddingInline(value.cssValue)
  }

  func paddingInline(_ value: Length) -> Style {
    appending(Self.paddingInline(value))
  }

  static func paddingBlockStart(_ value: Length) -> Style {
    .paddingBlockStart(value.cssValue)
  }

  func paddingBlockStart(_ value: Length) -> Style {
    appending(Self.paddingBlockStart(value))
  }

  static func gap(_ value: Length) -> Style {
    .gap(value.cssValue)
  }

  func gap(_ value: Length) -> Style {
    appending(Self.gap(value))
  }

  static func columnGap(_ value: Length) -> Style {
    .columnGap(value.cssValue)
  }

  func columnGap(_ value: Length) -> Style {
    appending(Self.columnGap(value))
  }

  static func top(_ value: Length) -> Style {
    .top(value.cssValue)
  }

  func top(_ value: Length) -> Style {
    appending(Self.top(value))
  }
}
