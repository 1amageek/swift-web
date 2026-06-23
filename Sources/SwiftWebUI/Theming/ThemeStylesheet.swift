import SwiftHTML

enum ThemeStylesheet {
  static func stylesheet(for theme: Theme, styleSystem: StyleSystem) -> Stylesheet {
    Stylesheet {
      componentStylesheet
      materialStylesheet
      atRulesStylesheet
      rule("[data-theme=\"\(cssAttributeString(theme.name))\"]") {
        theme.cssVariableStyle
      }
      rule("[data-style-system=\"\(cssAttributeString(styleSystem.id))\"]") {
        styleSystem.cssVariableStyle
      }
    }
  }

  /// The full stylesheet text. Every rule — including the `@supports`/`@media`/
  /// `@keyframes` at-rules — is modeled in the typed `Stylesheet`, so there is no
  /// raw CSS string.
  static func css(for theme: Theme, styleSystem: StyleSystem) -> String {
    stylesheet(for: theme, styleSystem: styleSystem).cssText
  }

  private static func cssAttributeString(_ value: String) -> String {
    var escaped = ""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22:
        escaped.append("\\22 ")
      case 0x5C:
        escaped.append("\\5C ")
      case 0x0A:
        escaped.append("\\A ")
      case 0x0C:
        escaped.append("\\C ")
      case 0x0D:
        escaped.append("\\D ")
      default:
        if scalar.value >= 0x20 && scalar.value <= 0x7E {
          escaped.unicodeScalars.append(scalar)
        } else {
          escaped.append("\\")
          escaped.append(String(scalar.value, radix: 16, uppercase: true))
          escaped.append(" ")
        }
      }
    }
    return escaped
  }

  private static var componentStylesheet: Stylesheet {
    Stylesheet {
      rule(
        """
        html,
        body
        """
      ) {
        .minHeight("100%")
      }
      rule("body") {
        .margin("0")
      }
      rule(".swui-root") {
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
      // A theme scope nested inside another (`.environment(\.theme,)` applied
      // to a subtree, e.g. a preview matrix cell) is an inner surface, not the
      // page canvas. It keeps the themed background so the subtree previews on
      // its own theme, but drops the page-root fills: it sizes to its content
      // instead of stretching to `min-height: 100%` (which would overrun
      // siblings), rounds its corners so the themed fill frames a rounded
      // container instead of poking square corners past it, and pads its content
      // so elevation is not clipped at a hard background seam.
      rule(".swui-root .swui-root") {
        .minHeight("auto")
          .borderRadius("var(--swui-radius-large)")
          .padding(.space(.medium))
      }
      // A page opts into a viewport-filling surface by setting the document body
      // class to `swui-viewport`: the body is sized to the viewport and clips its
      // own overflow, so a descendant ScrollView scrolls internally (with native
      // bounce) instead of the whole page scrolling.
      rule("body.swui-viewport") {
        .height("100dvh")
          .overflow("hidden")
      }
      rule("body.swui-viewport > .swui-root") {
        .height("100%")
          .minHeight("0")
      }
      rule(
        """
        .swui-vstack,
        .swui-hstack,
        .swui-lazy-vstack,
        .swui-lazy-hstack,
        .swui-toolbar
        """
      ) {
        .display("flex")
          .boxSizing("border-box")
      }
      rule(
        """
        .swui-vstack,
        .swui-lazy-vstack
        """
      ) {
        .flexDirection("column")
      }
      rule(
        """
        .swui-hstack,
        .swui-lazy-hstack,
        .swui-toolbar
        """
      ) {
        .flexDirection("row")
          .alignItems("center")
          // SwiftUI's HStack lays its children on a single row and never wraps
          // (wrapping is Grid/ViewThatFits territory). Match that so a row of
          // controls stays one line and overflows rather than dropping onto a
          // second row.
          .flexWrap("nowrap")
      }
      rule(
        """
        .swui-lazy-vstack > *,
        .swui-lazy-hstack > *
        """
      ) {
        .contentVisibility("auto")
          .containIntrinsicSize("var(--swui-lazy-intrinsic-size)")
      }
      rule(
        """
        .swui-lazy-vgrid,
        .swui-lazy-hgrid
        """
      ) {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(
        """
        .swui-lazy-vgrid > *,
        .swui-lazy-hgrid > *
        """
      ) {
        .contentVisibility("auto")
          .containIntrinsicSize("var(--swui-lazy-intrinsic-size)")
      }
      rule(".swui-zstack") {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(".swui-zstack > *") {
        .gridArea("1 / 1")
      }
      rule(".swui-frame") {
        .display("flex")
      }
      // `.animation(_:value:)` wraps its subtree in this scope, which carries the
      // inherited `--swui-animation` custom property without adding a box.
      rule(".swui-animation-scope") {
        .display("contents")
      }
      // Every element inside an animation scope transitions *every* animatable
      // property at the scope's `--swui-animation` timing (instant when no
      // `.animation(_:)` is in scope, via the `0s` fallback). This is what makes
      // `.animation` apply subtree-wide — the way SwiftUI does, animating whatever
      // a descendant changes (color, backdrop-filter, layout, …) — rather than
      // only a hand-picked few. Declared before the control rules so a control's
      // own transition still wins on its element.
      rule(".swui-animation-scope *") {
        .transition("all var(--swui-animation, 0s)")
      }
      // `.transition(_:)` insertion/removal. The "from" state is published as
      // --swui-enter-*/--swui-exit-* custom properties on the element; insertion
      // animates from the @starting-style values (below) and removal animates to
      // the exit values once the runtime adds `.swui-exiting`.
      rule(".swui-transition") {
        .transition(
          "opacity var(--swui-transition, 0.3s ease), "
            + "transform var(--swui-transition, 0.3s ease)"
        )
      }
      rule(".swui-transition.swui-exiting") {
        .opacity("var(--swui-exit-opacity, 1)")
          .transform("var(--swui-exit-transform, none)")
      }
      rule(".swui-layered") {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(".swui-layered > .swui-layer") {
        .gridArea("1 / 1")
          .boxSizing("border-box")
      }
      rule(".swui-layer-background") {
        .zIndex("0")
      }
      rule(".swui-layer-content") {
        .zIndex("1")
      }
      rule(".swui-layer-overlay") {
        .zIndex("2")
      }
      rule(".swui-spacer") {
        .flex("1 1 auto")
      }
      rule(".swui-grid") {
        .display("grid")
          .width("fit-content")
          .rowGap("var(--swui-grid-vertical-spacing)")
          .boxSizing("border-box")
      }
      // SwiftUI Grid lays each GridRow's cells into auto-sized columns; mirror
      // that with a per-row column grid (a real `display: grid`, not a table).
      // Equal-width cells line up across rows.
      rule(".swui-grid-row") {
        .display("grid")
          .custom("grid-auto-flow", "column")
          .custom("grid-auto-columns", "minmax(0, max-content)")
          .custom("column-gap", "var(--swui-grid-horizontal-spacing)")
          .alignItems("var(--swui-grid-cell-vertical-alignment)")
      }
      rule(".swui-grid-system") {
        .display("grid")
          .gridTemplateColumns("repeat(var(--swui-grid-system-columns), minmax(0, 1fr))")
          .columnGap(.gridSystemGutter)
          .rowGap("var(--swui-grid-system-gutter)")
        .width("100%")
          .boxSizing("border-box")
          .margin("0 auto")
          .paddingInline(.pageInlinePadding)
      }
      rule(".swui-grid-pane") {
        .boxSizing("border-box")
          .minWidth("0")
      }
      // GroupBox composes the shared material primitive and keeps only the
      // container chrome: padding, border, radius, and the elevated drop shadow.
      rule(".swui-group-box") {
          .display("flex")
          .flexDirection("column")
          .alignItems("flex-start")
          .border("var(--swui-container-border)")
          .borderRadius("var(--swui-container-radius)")
          .boxSizing("border-box")
          .boxShadow("var(--swui-container-shadow)")
          .padding(.space(.medium))
      }
      rule(".swui-group-box-title") {
        .margin("0 0 var(--swui-space-sm) 0")
      }
      // The toolbar reads as a floating glass bar: its fill + backdrop come
      // from the shared `bar` material (composed in `Toolbar`); this rule
      // adds the padding and radius that give the bar its shape.
      rule(".swui-toolbar") {
        .padding(.space(.small), .space(.medium))
          .borderRadius("var(--swui-radius-large)")
      }
      rule(".swui-label-style-titleOnly .swui-label-icon") {
        .display("none")
      }
      // Icon-only labels hide the title visually but keep it in the
      // accessibility tree (the icon itself is aria-hidden), so the control
      // still has an accessible name.
      rule(".swui-label-style-iconOnly .swui-label-title") {
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
      rule(
        """
        .swui-text-field-style-plain,
        .swui-text-editor.swui-text-field-style-plain
        """
      ) {
        .background("transparent")
          .border("0")
          .boxShadow("none")
      }
      rule(".swui-text-field-style-squareBorder") {
        .borderRadius("0")
      }
      rule(".swui-list-style-plain") {
        .border("0")
          .background("transparent")
      }
      rule(
        """
        .swui-list-style-grouped,
        .swui-list-style-insetGrouped
        """
      ) {
        .padding(.space(.small))
          .borderRadius("var(--swui-radius-large)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 72%, transparent)")
      }
      rule(".swui-toggle-style-checkbox .swui-toggle-control") {
        .borderRadius("var(--swui-radius-small)")
      }
      rule(".swui-tabview-style-page .swui-tab-item") {
        .display("none")
      }
      // MARK: Sizing intent markers (parent-axis aware)
      // Horizontal fill under a column parent -> stretch the cross axis.
      rule(
        """
        .swui-vstack > .swui-fill-h,
        .swui-lazy-vstack > .swui-fill-h,
        .swui-group-box > .swui-fill-h,
        .swui-zstack > .swui-fill-h,
        .swui-frame > .swui-fill-h,
        .swui-scroll-view > .swui-fill-h,
        .swui-root > .swui-fill-h
        """
      ) {
        .alignSelf("stretch")
      }
      // Horizontal fill under a row parent -> grow along the main axis.
      rule(
        """
        .swui-hstack > .swui-fill-h,
        .swui-lazy-hstack > .swui-fill-h,
        .swui-toolbar > .swui-fill-h
        """
      ) {
        .flex("1 1 0%")
          .minWidth("0")
      }
      // Vertical fill under a row parent -> stretch the cross axis.
      rule(
        """
        .swui-hstack > .swui-fill-v,
        .swui-lazy-hstack > .swui-fill-v,
        .swui-toolbar > .swui-fill-v
        """
      ) {
        .alignSelf("stretch")
      }
      // Vertical fill under a column parent -> grow along the main axis.
      rule(
        """
        .swui-vstack > .swui-fill-v,
        .swui-lazy-vstack > .swui-fill-v,
        .swui-group-box > .swui-fill-v,
        .swui-frame > .swui-fill-v,
        .swui-root > .swui-fill-v
        """
      ) {
        .flex("1 1 0%")
          .minHeight("0")
      }
      // Upward propagation: a container holding a horizontal-fill
      // descendant is itself horizontally greedy in its column parent.
      rule(
        """
        .swui-vstack:has(.swui-fill-h),
        .swui-lazy-vstack:has(.swui-fill-h),
        .swui-hstack:has(.swui-fill-h),
        .swui-lazy-hstack:has(.swui-fill-h),
        .swui-group-box:has(.swui-fill-h),
        .swui-toolbar:has(.swui-fill-h)
        """
      ) {
        .alignSelf("stretch")
      }
      // A row that contains a Spacer is horizontally greedy; carry that
      // intent up to one enclosing column level.
      rule(
        """
        .swui-hstack:has(> .swui-spacer),
        .swui-toolbar:has(> .swui-spacer),
        .swui-group-box:has(.swui-hstack > .swui-spacer),
        .swui-group-box:has(.swui-toolbar > .swui-spacer),
        .swui-vstack:has(.swui-hstack > .swui-spacer),
        .swui-vstack:has(.swui-toolbar > .swui-spacer)
        """
      ) {
        .alignSelf("stretch")
      }
      // Row-parent override: a greedy column/container that is itself a row
      // item grows on the main axis instead of stretching the cross axis.
      rule(
        """
        .swui-hstack > .swui-vstack:has(.swui-fill-h),
        .swui-hstack > .swui-lazy-vstack:has(.swui-fill-h),
        .swui-hstack > .swui-group-box:has(.swui-fill-h),
        .swui-toolbar > .swui-vstack:has(.swui-fill-h),
        .swui-toolbar > .swui-group-box:has(.swui-fill-h)
        """
      ) {
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
      rule(
        """
        .swui-frame.swui-fill-h > .swui-vstack,
        .swui-frame.swui-fill-h > .swui-hstack,
        .swui-frame.swui-fill-h > .swui-lazy-vstack,
        .swui-frame.swui-fill-h > .swui-lazy-hstack,
        .swui-frame.swui-fill-h > .swui-zstack,
        .swui-frame.swui-fill-h > .swui-group-box,
        .swui-frame.swui-fill-h > .swui-scroll-view,
        .swui-frame.swui-fill-h > .swui-grid-system,
        .swui-frame.swui-fill-h > .swui-frame
        """
      ) {
        .flex("1 1 0%")
          .minWidth("0")
      }
      rule(
        """
        .swui-frame.swui-fill-v > .swui-vstack,
        .swui-frame.swui-fill-v > .swui-hstack,
        .swui-frame.swui-fill-v > .swui-lazy-vstack,
        .swui-frame.swui-fill-v > .swui-lazy-hstack,
        .swui-frame.swui-fill-v > .swui-zstack,
        .swui-frame.swui-fill-v > .swui-group-box,
        .swui-frame.swui-fill-v > .swui-scroll-view,
        .swui-frame.swui-fill-v > .swui-grid-system,
        .swui-frame.swui-fill-v > .swui-frame
        """
      ) {
        .alignSelf("stretch")
          .minHeight("0")
      }
      // Explicit hug blocks fill and propagation. Declared after the
      // fill/:has rules so equal-specificity selectors win by source order.
      rule(".swui-hug-h") {
        .alignSelf("flex-start")
      }
      rule(
        """
        .swui-vstack.swui-hug-h,
        .swui-lazy-vstack.swui-hug-h,
        .swui-hstack.swui-hug-h,
        .swui-lazy-hstack.swui-hug-h,
        .swui-group-box.swui-hug-h,
        .swui-toolbar.swui-hug-h
        """
      ) {
        .alignSelf("flex-start")
      }
      rule(
        """
        .swui-hstack > .swui-hug-h,
        .swui-lazy-hstack > .swui-hug-h,
        .swui-toolbar > .swui-hug-h
        """
      ) {
        .flex("0 0 auto")
          .alignSelf("auto")
      }
      // A fixed-width column that also fills height (e.g. a scrollable sidebar):
      // hug-h pins the width via flex above, but fill-v must still stretch it to
      // the row height so an inner ScrollView is bounded and can scroll. More
      // specific than the hug-h rule, so the cross-axis stretch wins.
      rule(
        """
        .swui-hstack > .swui-hug-h.swui-fill-v,
        .swui-lazy-hstack > .swui-hug-h.swui-fill-v,
        .swui-toolbar > .swui-hug-h.swui-fill-v
        """
      ) {
        .alignSelf("stretch")
          .minHeight("0")
      }
      // Vertical hug, parent-axis aware.
      rule(
        """
        .swui-vstack > .swui-hug-v,
        .swui-lazy-vstack > .swui-hug-v,
        .swui-group-box > .swui-hug-v,
        .swui-root > .swui-hug-v
        """
      ) {
        .flex("0 0 auto")
      }
      rule(
        """
        .swui-hstack > .swui-hug-v,
        .swui-lazy-hstack > .swui-hug-v,
        .swui-toolbar > .swui-hug-v
        """
      ) {
        .alignSelf("flex-start")
      }
      rule(".swui-heading") {
        .margin("0")
          .color("var(--swui-text)")
          .letterSpacing("0")
      }
      rule(".swui-heading-page") {
        .fontSize("var(--swui-heading-page-size)")
          .lineHeight("var(--swui-heading-page-line-height)")
      }
      rule(".swui-heading-section") {
        .fontSize("var(--swui-heading-section-size)")
          .lineHeight("1.2")
      }
      rule(".swui-heading-subsection") {
        .fontSize("var(--swui-heading-subsection-size)")
          .lineHeight("1.25")
      }
      rule(".swui-text") {
        .margin("0")
          .color("var(--swui-text)")
      }
      rule(".swui-inline-code") {
        .display("inline-block")
          .padding(.zero, .em(0.35))
          .border("1px solid var(--swui-border)")
          .borderRadius("var(--swui-radius-small)")
          .background("color-mix(in srgb, var(--swui-surface-raised) 88%, var(--swui-accent))")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.9em")
          .lineHeight("1.5")
      }
      rule(".swui-preformatted") {
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
      rule(".swui-code-block") {
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
      rule(".swui-code-block-content") {
        .display("block")
          .minWidth("max-content")
      }
      rule(".swui-code-line") {
        .display("grid")
          .gridTemplateColumns("minmax(3ch, auto) 1fr")
          .columnGap(.space(.medium))
          .padding(.zero, .space(.medium))
          .whiteSpace("pre")
      }
      rule(".swui-code-line-plain") {
        .gridTemplateColumns("1fr")
      }
      rule(".swui-code-line-number") {
        .color("var(--swui-text-muted)")
          .fontVariantNumeric("tabular-nums")
          .textAlign("right")
          .userSelect("none")
      }
      rule(".swui-code-line-content") {
        .whiteSpace("pre")
      }
      rule(".swui-button") {
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
      rule(".swui-control-mini") {
        .minHeight("var(--swui-control-mini-height)")
          .paddingInline(.space(.small))
          .fontSize("12px")
      }
      rule(".swui-control-small") {
        .minHeight("var(--swui-control-small-height)")
          .paddingInline(.space(.medium))
          .fontSize("14px")
      }
      rule(".swui-control-regular") {
        .minHeight("var(--swui-control-regular-height)")
      }
      rule(".swui-control-large") {
        .minHeight("var(--swui-control-large-height)")
          .paddingInline(.space(.xlarge))
          .fontSize("17px")
      }
      rule(".swui-control-extraLarge") {
        .minHeight("var(--swui-control-extra-large-height)")
          .paddingInline(.space(.xlarge))
          .fontSize("19px")
      }
      rule(".swui-button-primary") {
        .color("var(--swui-button-primary-foreground)")
          // Resolve the control tint on the button element itself so the inline
          // per-button --swui-control-tint override wins. Falling back to the
          // style-system default avoids depending on an ancestor-resolved token.
          .background("var(--swui-control-tint, var(--swui-button-primary-background))")
      }
      // The bordered (secondary) button surface comes from the shared material.
      // The component emits semantic classes only; this stylesheet feeds the
      // secondary background token in as the material tint so the active
      // StyleSystem owns translucency, blur, rim, and solid fallback.
      rule(".swui-button-secondary") {
        .color("var(--swui-button-secondary-foreground)")
          .custom("--swui-material-tint", "var(--swui-button-secondary-background)")
          .borderColor("var(--swui-button-secondary-border)")
      }
      rule(".swui-button-plain") {
        .color("var(--swui-control-tint, var(--swui-button-plain-foreground))")
          .background("transparent")
          .borderColor("transparent")
          .paddingInline(.zero)
      }
      // Glass buttons take their fill from the shared `swui-glass` recipe, so
      // these rules only set semantic text/border behavior. The plain glass
      // keeps the neutral surface tint; the prominent glass is washed with the
      // control tint.
      rule(".swui-button-glass") {
        .color("var(--swui-text)")
          .borderColor("transparent")
      }
      rule(".swui-button-glass-prominent") {
        .color("var(--swui-accent-text)")
          .borderColor("transparent")
          .custom("--swui-material-tint", "var(--swui-control-tint, var(--swui-accent))")
      }
      // Shift the material tint on hover (rather than painting an opaque
      // background over the glass) so the frosted surface is preserved.
      rule(".swui-button-secondary:hover") {
        .custom("--swui-material-tint", "var(--swui-button-secondary-hover-background)")
      }
      // Press feedback is part of a button's own interaction (its responsibility,
      // not the caller's): every enabled button dips slightly when pressed,
      // eased by the transform transition above.
      rule(".swui-button:not(:disabled):not(.swui-control-disabled):active") {
        .transform("scale(0.97)")
      }
      rule(
        """
        .swui-control-disabled,
        .swui-button:disabled,
        .swui-text-field:disabled,
        .swui-picker:disabled,
        .swui-slider:disabled
        """
      ) {
        .cursor("default")
          .opacity("var(--swui-control-disabled-opacity)")
      }
      rule(".swui-modifier") {
        .boxSizing("border-box")
      }
      rule(".swui-box-modifier") {
        .display("block")
      }
      rule(
        """
        .swui-text-style-modifier,
        .swui-semantic-modifier
        """
      ) {
        .display("contents")
      }
      rule(".swui-text-style-modifier .swui-text") {
        .fontFamily("inherit")
          .fontSize("inherit")
          .fontStyle("inherit")
          .fontWeight("inherit")
          .textAlign("inherit")
          .textDecoration("inherit")
      }
      rule(".swui-style-foreground .swui-text") {
        .color("inherit")
      }
      rule(".swui-label") {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.small))
      }
      rule(".swui-label-icon") {
        .display("inline-flex")
          .alignItems("center")
          .color("currentColor")
      }
      rule(".swui-label-title") {
        .display("inline")
      }
      // The badge fill comes from the shared material (Badge composes
      // `.thinMaterial`); this rule keeps the badge's own border, radius,
      // padding, and text color.
      rule(".swui-badge") {
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
      rule(".swui-form") {
        .margin("0")
          .width("fit-content")
          .maxWidth("100%")
      }
      rule(".swui-button-action-form") {
        .display("inline-flex")
      }
      // SwiftUI links are accent-tinted by default and not underlined. Default to
      // the accent (so a bare Link is a visible link) and drop the user-agent
      // underline; inside a foregroundStyle scope the link inherits that color
      // instead, mirroring `.swui-style-foreground .swui-text`.
      rule(".swui-link") {
        .color("var(--swui-accent)")
          .textDecoration("none")
      }
      rule(".swui-style-foreground .swui-link") {
        .color("inherit")
      }
      rule(".swui-navigation-stack") {
        .display("grid")
          .gap(.navigationGap)
          .boxSizing("border-box")
          .width("fit-content")
          .maxWidth("100%")
      }
      rule(".swui-navigation-link") {
        .color("var(--swui-navigation-link-foreground)")
          .textDecoration("var(--swui-navigation-link-decoration)")
      }
      rule(".swui-navigation-link:hover") {
        .textDecoration("var(--swui-navigation-link-hover-decoration)")
      }
      rule(".swui-scroll-view") {
        .boxSizing("border-box")
          .maxWidth("100%")
          .maxHeight("100%")
          .overscrollBehavior("contain")
      }
      rule(".swui-scroll-view-hidden-indicators") {
        .scrollbarWidth("none")
      }
      rule(".swui-scroll-view-hidden-indicators::-webkit-scrollbar") {
        .display("none")
      }
      rule(".swui-divider") {
        .background("var(--swui-border)")
          .flex("0 0 auto")
          .width("100%")
          .height("1px")
      }
      rule(
        """
        .swui-hstack > .swui-divider,
        .swui-lazy-hstack > .swui-divider,
        .swui-toolbar > .swui-divider
        """
      ) {
        .width("1px")
          .height("auto")
          .alignSelf("stretch")
      }
      rule(".swui-section") {
        .display("grid")
          .gap(.space(.medium))
          .boxSizing("border-box")
      }
      rule(".swui-section-footer") {
        .fontSize("13px")
          .color("var(--swui-text-muted)")
      }
      rule(".swui-list") {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(".swui-list-row") {
        .display("flex")
          .alignItems("center")
          .gap(.space(.small))
          .boxSizing("border-box")
      }
      rule(".swui-list-row .swui-text") {
        .lineHeight("1.35")
      }
      rule(".swui-list-row > .swui-text:first-child") {
        .fontWeight("500")
      }
      // Secondary text in a row (anything after the leading title) reads smaller.
      // Keyed to structural position rather than colour, so muting (handled by
      // `.foregroundStyle(.secondary)`) and sizing stay independent concerns.
      rule(".swui-list-row > .swui-text:not(:first-child)") {
        .fontSize("13px")
      }
      rule(".swui-field") {
        .display("grid")
          .gap(.space(.xsmall))
          .color("var(--swui-text)")
      }
      rule(".swui-picker-field") {
        .display("grid")
          .gap(.space(.xsmall))
      }
      rule(
        """
        .swui-field-label,
        .swui-toggle-label
        """
      ) {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // The field fill comes from the shared material (TextField/Picker/
      // DatePicker compose `.thinMaterial`); this rule keeps the field's
      // border, radius, padding, and text color. `<input>`/`<select>` are
      // replaced elements, so the material's `::before` rim/refraction
      // overlay does not paint, but its fill and backdrop blur still apply.
      rule(
        """
        .swui-text-field,
        .swui-picker,
        .swui-date-picker
        """
      ) {
        .minHeight("var(--swui-control-regular-height)")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-field-radius)")
          .padding(.fieldPadding)
          .boxSizing("border-box")
          .color("var(--swui-text)")
          .font("inherit")
      }
      rule(".swui-slider") {
        .accentColor("var(--swui-control-tint, var(--swui-accent))")
          .minWidth("160px")
      }
      rule(".swui-toggle") {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.small))
          .color("var(--swui-text)")
          .cursor("pointer")
      }
      rule(".swui-toggle-input") {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
      }
      // The off-state track fill comes from the shared material (Toggle
      // composes `.thinMaterial`); this rule keeps the track's size,
      // pill radius, and border. The checked rules below paint the track
      // solid accent, and the thumb lives on the track's own `::after`.
      rule(".swui-toggle-control") {
        .width("var(--swui-toggle-width)")
          .height("var(--swui-toggle-height)")
          .borderRadius("var(--swui-radius-pill)")
          .border("1px solid var(--swui-border)")
          .boxSizing("border-box")
          .position("relative")
      }
      rule(".swui-toggle-control::after") {
        .content("\"\"")
          .position("absolute")
          .width("var(--swui-toggle-thumb-size)")
          .height("var(--swui-toggle-thumb-size)")
          .left("var(--swui-toggle-thumb-offset)")
          .top(.toggleThumbOffset)
          .borderRadius("999px")
          .background("var(--swui-text-muted)")
          .transition("transform var(--swui-animation, var(--swui-motion-quick)), background var(--swui-animation, var(--swui-motion-quick))")
      }
      rule(".swui-toggle-input:checked + .swui-toggle-control") {
        .background("var(--swui-accent)")
          .borderColor("var(--swui-accent)")
      }
      rule(".swui-toggle-input:checked + .swui-toggle-control::after") {
        .transform("translateX(var(--swui-toggle-checked-thumb-offset))")
          .background("var(--swui-accent-text)")
      }
      rule(".swui-image") {
        .maxWidth("100%")
          .height("auto")
          .display("inline-block")
      }
      // An SVG symbol scales with the surrounding text (slightly larger, like an
      // SF Symbol) and inherits its color via fill="currentColor".
      rule(".swui-symbol") {
        .width("1.15em")
          .height("1.15em")
          .verticalAlign("-0.15em")
          .flexShrink("0")
      }
      // The text fallback for an unknown identifier keeps the monospace label.
      rule(".swui-symbol-text") {
        .width("auto")
          .height("auto")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.85em")
          .lineHeight("1")
          .verticalAlign("baseline")
      }

      // MARK: ProgressView
      // Container stacks an optional label over the bar/spinner.
      rule(".swui-progress") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
          .boxSizing("border-box")
      }
      rule(".swui-progress-label") {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // The track fill comes from the composed `.ultraThinMaterial`; the
      // value paints solid accent. `<progress>` is a replaced element, so
      // its `::before` overlay does not render and only the fill/blur apply.
      rule(".swui-progress-bar") {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("100%")
          .height("6px")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(".swui-progress-bar::-webkit-progress-bar") {
        .background("transparent")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-progress-bar::-webkit-progress-value") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-progress-bar::-moz-progress-bar") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      // Indeterminate spinner; `@keyframes swui-spin` is appended raw in
      // `css(for:)` because keyframes are not expressible as a flat rule.
      rule(".swui-progress-spinner") {
        .width("20px")
          .height("20px")
          .borderRadius("999px")
          .border("2px solid color-mix(in srgb, var(--swui-text-muted) 30%, transparent)")
          .borderTopColor("var(--swui-control-tint, var(--swui-accent))")
          .animation("swui-spin 0.7s linear infinite")
          .boxSizing("border-box")
      }

      // MARK: Gauge
      rule(".swui-gauge") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
          .boxSizing("border-box")
      }
      rule(".swui-gauge-label") {
        .color("var(--swui-text-muted)")
          .fontSize("var(--swui-field-label-size)")
      }
      // `<meter>` track fill comes from the composed `.ultraThinMaterial`;
      // the value paints solid accent. Like `<progress>` it is replaced, so
      // only the fill/blur apply and the rim overlay does not render.
      rule(".swui-gauge-meter") {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("100%")
          .height("8px")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(".swui-gauge-meter::-webkit-meter-bar") {
        .background("transparent")
          .border("none")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-webkit-meter-optimum-value") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-webkit-meter-suboptimum-value") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-webkit-meter-even-less-good-value") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-moz-meter-bar") {
        .background("var(--swui-control-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }

      // MARK: DisclosureGroup
      // `<details>` is not replaced, so the composed `.regularMaterial`
      // paints its full recipe (fill + rim + refraction) on the container.
      rule(".swui-disclosure-group") {
        .borderRadius("var(--swui-container-radius)")
          .border("var(--swui-container-border)")
          .overflow("hidden")
          .boxSizing("border-box")
      }
      rule(".swui-disclosure-summary") {
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
      rule(".swui-disclosure-summary::-webkit-details-marker") {
        .display("none")
      }
      rule(".swui-disclosure-content") {
        .padding(.zero, .space(.medium), .space(.medium), .space(.medium))
          .color("var(--swui-text)")
      }

      // MARK: TextEditor
      // `<textarea>` is a form control: the composed `.thinMaterial` fill
      // and backdrop blur apply, while the rim overlay does not render.
      rule(".swui-text-editor") {
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
      rule(".swui-color-picker") {
        .display("flex")
          .flexDirection("row")
          .alignItems("center")
          .justifyContent("space-between")
          .gap(.space(.small))
          .cursor("pointer")
      }
      // No material on the swatch — it must show the chosen color verbatim.
      rule(".swui-color-picker-input") {
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
      rule(".swui-color-picker-input::-webkit-color-swatch-wrapper") {
        .padding(.zero)
      }
      rule(".swui-color-picker-input::-webkit-color-swatch") {
        .border("none")
          .borderRadius("calc(var(--swui-radius-small) - 1px)")
      }
      rule(".swui-color-picker-input::-moz-color-swatch") {
        .border("none")
          .borderRadius("calc(var(--swui-radius-small) - 1px)")
      }

      // MARK: Picker — segmented / inline
      // The `.segmented` style composes the `bar` material as a pill track;
      // each option is a hidden radio whose label span is the visual
      // segment, highlighted via the same `input:checked ~ label` sibling
      // pattern the toggle uses (no `:has()` dependency). The `.inline`
      // style is a plain vertical radio list with a leading marker.
      rule(".swui-picker-segmented") {
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
      rule(".swui-picker-inline") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
      }
      rule(".swui-picker-segment") {
        .position("relative")
          .display("inline-flex")
          .cursor("pointer")
          .color("var(--swui-text)")
      }
      rule(".swui-picker-segmented .swui-picker-segment") {
        .flex("1 0 auto")
          .minWidth("max-content")
      }
      rule(".swui-picker-segment-input") {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
          .width("0")
          .height("0")
      }
      rule(".swui-picker-segment-label") {
        .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .width("100%")
          .boxSizing("border-box")
          .userSelect("none")
          .fontSize("var(--swui-field-label-size)")
      }
      rule(".swui-picker-segmented .swui-picker-segment-label") {
        .minHeight("calc(var(--swui-control-regular-height) - 6px)")
          .padding(.px(6), .px(14))
          .borderRadius("calc(var(--swui-button-radius) - 2px)")
          .textAlign("center")
          .lineHeight("1")
          .whiteSpace("nowrap")
          .transition("background var(--swui-animation, var(--swui-motion-quick)), color var(--swui-animation, var(--swui-motion-quick))")
      }
      rule(".swui-picker-segmented .swui-picker-segment-input:checked ~ .swui-picker-segment-label")
      {
        .background("var(--swui-accent)")
          .color("var(--swui-accent-text)")
      }
      rule(".swui-picker-inline .swui-picker-segment-label") {
        .justifyContent("flex-start")
          .gap(.space(.small))
          .padding(.space(.xsmall), .zero)
      }
      rule(".swui-picker-inline .swui-picker-segment-label::before") {
        .content("\"\"")
          .width("18px")
          .height("18px")
          .borderRadius("999px")
          .border("2px solid var(--swui-border)")
          .boxSizing("border-box")
          .flex("0 0 auto")
      }
      rule(
        ".swui-picker-inline .swui-picker-segment-input:checked ~ .swui-picker-segment-label::before"
      ) {
        .borderColor("var(--swui-accent)")
          .background(
            "radial-gradient(circle at center, var(--swui-accent) 0 5px, transparent 6px)")
      }
      rule(".swui-picker-segment-input:focus-visible ~ .swui-picker-segment-label") {
        .outline("2px solid var(--swui-accent)")
          .outlineOffset("2px")
      }

      // MARK: Menu
      // `<details>` anchors a floating panel under an interactive-glass
      // summary. The native disclosure triangle is hidden; the panel
      // composes `regularMaterial` plus the container elevation shadow.
      rule(".swui-menu") {
        .position("relative")
          .display("inline-block")
      }
      rule(".swui-menu-label") {
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
      rule(".swui-menu-label::-webkit-details-marker") {
        .display("none")
      }
      rule(".swui-menu-content") {
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
      rule(".swui-tabview") {
        .display("flex")
          .flexWrap("wrap")
          .alignItems("center")
          .gap(.space(.xsmall))
      }
      rule(".swui-tab") {
        .display("contents")
      }
      rule(".swui-tab-input") {
        .position("absolute")
          .opacity("0")
          .pointerEvents("none")
          .width("0")
          .height("0")
      }
      rule(".swui-tab-item") {
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
      rule(".swui-tab-item:has(.swui-tab-input:checked)") {
        .background("var(--swui-accent)")
          .color("var(--swui-accent-text)")
      }
      rule(".swui-tab-item:has(.swui-tab-input:focus-visible)") {
        .outline("2px solid var(--swui-accent)")
          .outlineOffset("2px")
      }
      rule(".swui-tab-panel") {
        .order("1")
          .flexBasis("100%")
          .width("100%")
          .display("none")
          .paddingBlockStart(.space(.small))
      }
      rule(".swui-tab-item:has(.swui-tab-input:checked) + .swui-tab-panel") {
        .display("block")
      }

      // MARK: Searchable
      // The search field stacks above the searchable content. It composes
      // the shared thin material for its fill and backdrop blur; the rule
      // keeps its border, radius, padding, and text color.
      rule(".swui-searchable") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(".swui-search-bar") {
        .display("flex")
      }
      rule(".swui-search-field") {
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
      rule(".swui-search-suggestion-host, .swui-search-scoped") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(".swui-search-suggestions") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.xsmall))
      }
      rule(".swui-search-tokenized") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.small))
      }
      rule(".swui-search-tokens") {
        .display("flex")
          .gap(.space(.xsmall))
          .flexWrap("wrap")
      }
      rule(".swui-search-token") {
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
      rule(".swui-search-scopes") {
        .display("flex")
          .gap(.space(.xsmall))
          .flexWrap("wrap")
      }
      rule(".swui-search-scope") {
        .display("inline-flex")
          .alignItems("center")
          .gap(.space(.xsmall))
      }
      // MARK: Presentation (alert / confirmationDialog / sheet / popover)
      // The shared `<dialog>` overlay composes the material primitive; this
      // rule keeps the border, radius, drop shadow, sizing, and modal layout.
      // A `<dialog>` without `open` is `display: none` by UA default, so the
      // overlay costs no layout while hidden.
      rule(".swui-presentation") {
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
      rule(".swui-presentation[open]") {
        .position("fixed")
          .top(.zero)
          .right("0")
          .bottom("0")
          .left("0")
      }
      // The scrim only paints for a true modal (top layer). Without the
      // runtime the dialog is in-flow and the page behind stays visible —
      // an explicit, documented degradation, not a silent fallback.
      rule(".swui-presentation::backdrop") {
        .background("color-mix(in srgb, var(--swui-text) 32%, transparent)")
          .custom("-webkit-backdrop-filter", "blur(2px)")
          .backdropFilter("blur(2px)")
      }
      rule(".swui-presentation-surface") {
        .display("flex")
          .flexDirection("column")
          .gap(.space(.medium))
          .padding(.space(.large))
          .boxSizing("border-box")
      }
      rule(".swui-presentation-title") {
        .margin("0")
          .fontSize("var(--swui-heading-subsection-size)")
          .lineHeight("1.25")
          .color("var(--swui-text)")
      }
      rule(".swui-presentation-message") {
        .margin("0")
          .color("var(--swui-text-muted)")
      }
      rule(".swui-presentation-actions") {
        .display("flex")
          .flexWrap("wrap")
          .gap(.space(.small))
          .justifyContent("flex-end")
      }
      // Action sheets stack their choices full width, matching the native
      // confirmation dialog layout.
      rule(".swui-presentation-confirmation .swui-presentation-actions") {
        .flexDirection("column")
          .alignItems("stretch")
      }
      // The sheet anchors to the bottom edge and squares its lower corners.
      rule(".swui-presentation-sheet") {
        .margin("auto auto 0 auto")
          .maxWidth("min(96vw, 40rem)")
          .borderBottomLeftRadius("0")
          .borderBottomRightRadius("0")
      }
      rule(".swui-presentation-sheet[open]") {
        .top(.auto)
      }
      // The popover reads as a compact panel. True source anchoring needs the
      // CSS anchor positioning API; until then it presents centered.
      rule(".swui-presentation-popover") {
        .maxWidth("min(92vw, 20rem)")
      }
      rule(".swui-grid-row > *") {
        .textAlign("var(--swui-grid-cell-horizontal-alignment)")
      }
      // Native form controls inherit the page font.
      rule(
        """
        input,
        button,
        select,
        textarea
        """
      ) {
        .fontFamily("inherit")
      }
      // Button size variants use native-like compact dimensions, which are
      // tighter than the generic `swui-control-*` sizing; they are
      // component-specific values that live in the stylesheet rather than the
      // component body.
      rule(".swui-button.swui-control-mini") {
        .minHeight("0")
          .padding(.px(4), .px(9))
          .borderRadius("var(--swui-radius-small)")
          .fontSize("11px")
      }
      rule(".swui-button.swui-control-small") {
        .minHeight("0")
          .padding(.px(5), .px(11))
          .fontSize("12px")
      }
      rule(".swui-button.swui-control-regular") {
        .minHeight("0")
          .padding(.px(7), .px(14))
          .fontSize("14px")
      }
      rule(".swui-button.swui-control-large") {
        .minHeight("0")
          .padding(.px(10), .px(20))
          .fontSize("16px")
      }
      rule(".swui-list-row:last-child") {
        .borderBottom("0")
      }
      rule(".swui-section-header") {
        .margin("0")
          .padding(.px(10), .px(14), .px(6), .px(14))
          .background("color-mix(in srgb, var(--swui-text-muted) 7%, transparent)")
          .color("var(--swui-text-muted)")
          .fontSize("11.5px")
          .fontWeight("700")
          .letterSpacing("0.05em")
          .textTransform("uppercase")
      }
      rule(
        """
        .swui-text-field:focus,
        .swui-text-editor:focus
        """
      ) {
        .borderColor("var(--swui-accent)")
      }
      rule(".swui-stepper") {
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
      rule(".swui-stepper-button") {
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
      rule(
        """
        .swui-stepper-value,
        .swui-stepper .val
        """
      ) {
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

  /// The single Liquid Glass recipe every chrome surface composes. A surface
  /// adds `.swui-material`/`.swui-glass` plus one level modifier; the level
  /// only scales the fill opacity, while blur, saturation, rim, and refraction
  /// come from the active design style's tokens. Solid styles set those tokens
  /// to no-op values, so the same markup reads as a plain surface.
  private static var materialStylesheet: Stylesheet {
    Stylesheet {
      // Base fill + backdrop. `isolation: isolate` establishes a stacking
      // context so the `::before` overlay paints above the fill but below
      // the element content (z-index: -1). The interactive multiplier folds
      // into the backdrop brightness and defaults to 1.
      // Shared base: a translucent fill and its own stacking context. The glass
      // blur is a fraction of the material blur so refraction can show through.
      rule(
        """
        .swui-material,
        .swui-glass
        """
      ) {
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
      rule(".swui-material") {
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
      rule(".swui-glass") {
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
      rule(".swui-material-ultra-thin") {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) - 2 * var(--swui-material-opacity-step))")
      }
      rule(".swui-material-thin") {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) - 1 * var(--swui-material-opacity-step))")
      }
      rule(".swui-material-regular") {
        .custom("--swui-material-level-opacity", "var(--swui-material-opacity)")
      }
      rule(".swui-material-thick") {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 1 * var(--swui-material-opacity-step))")
      }
      rule(".swui-material-ultra-thick") {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 2 * var(--swui-material-opacity-step))")
      }
      // The bar material (toolbars/tab bars) sits one step more frosted
      // than regular so chrome reads as a distinct layer over content.
      rule(".swui-material-bar") {
        .custom(
          "--swui-material-level-opacity",
          "calc(var(--swui-material-opacity) + 1 * var(--swui-material-opacity-step))")
      }
      // Interactive glass: pointer hover/press scales the backdrop
      // brightness through the multiplier the base recipe folds in.
      rule(".swui-glass-interactive") {
        .cursor("pointer")
      }
      rule(".swui-glass-interactive:hover") {
        .custom("--swui-material-interactive", "1.12")
      }
      rule(".swui-glass-interactive:active") {
        .custom("--swui-material-interactive", "0.94")
      }
      // Shared compositing context for grouped glass surfaces.
      rule(".swui-glass-container") {
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
      supports("not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px)))") {
        rule(".swui-material,\n.swui-glass") {
          .background("var(--swui-material-solid-fill)")
        }
        rule(".swui-material::before,\n.swui-glass::before") {
          .display("none")
        }
      }
      media("(prefers-reduced-transparency: reduce)") {
        rule(".swui-material,\n.swui-glass") {
          .background("var(--swui-material-solid-fill)")
        }
        rule(".swui-material::before,\n.swui-glass::before") {
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
      media("(prefers-reduced-motion: no-preference)") {
        rule(".swui-presentation[open] .swui-presentation-surface") {
          .animation("swui-present var(--swui-motion-standard) both")
        }
      }
      // Insertion "from" state for `.transition(_:)`: the freshly-inserted element
      // starts at its enter opacity/transform, then animates to the normal state.
      startingStyle {
        rule(".swui-transition") {
          .opacity("var(--swui-enter-opacity, 1)")
            .transform("var(--swui-enter-transform, none)")
        }
      }
      // Honor reduced-motion globally: collapse all transitions/animations to a
      // near-instant duration (the new `--swui-animation` path included).
      media("(prefers-reduced-motion: reduce)") {
        rule("*, *::before, *::after") {
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
