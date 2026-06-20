import SwiftHTML

enum ThemeStylesheet {
  static func stylesheet(for theme: Theme, styleSystem: StyleSystem) -> Stylesheet {
    Stylesheet {
      baseStylesheet
      materialStylesheet
      rule("[data-theme=\"\(cssAttributeString(theme.name))\"]") {
        theme.cssVariableStyle
      }
      rule("[data-style-system=\"\(cssAttributeString(styleSystem.id))\"]") {
        styleSystem.cssVariableStyle
      }
    }
  }

  /// The full stylesheet text, including the material fallback at-rules that
  /// `CSSRule` cannot express. `@supports`/`@media` blocks are appended raw
  /// because the rule model is flat (`selector { declarations }`); they are an
  /// explicit, designed degradation, not a silent fallback.
  static func css(for theme: Theme, styleSystem: StyleSystem) -> String {
    stylesheet(for: theme, styleSystem: styleSystem).cssText
      + "\n"
      + materialFallbackCSS
      + "\n"
      + progressSpinnerKeyframes
      + "\n"
      + designContractCSS
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

  private static var baseStylesheet: Stylesheet {
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
          .padding("var(--swui-space-md)")
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
          .flexWrap("wrap")
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
          .alignItems("stretch")
          .justifyItems("stretch")
          .boxSizing("border-box")
      }
      rule(".swui-grid-system") {
        .display("grid")
          .gridTemplateColumns("repeat(var(--swui-grid-system-columns), minmax(0, 1fr))")
          .columnGap("var(--swui-grid-system-gutter)")
          .rowGap("var(--swui-grid-system-gutter)")
        .width("100%")
          .boxSizing("border-box")
          .margin("0 auto")
          .paddingInline("var(--swui-page-inline-padding)")
      }
      rule(".swui-grid-pane") {
        .boxSizing("border-box")
          .minWidth("0")
      }
      // GroupBox composes the shared material primitive and keeps only the
      // container chrome: border, radius, and the elevated drop shadow.
      rule(".swui-group-box") {
          .display("flex")
          .flexDirection("column")
          .alignItems("flex-start")
          .border("var(--swui-container-border)")
          .borderRadius("var(--swui-container-radius)")
          .boxSizing("border-box")
          .boxShadow("var(--swui-container-shadow)")
      }
      rule(".swui-group-box-title") {
        .margin("0 0 var(--swui-space-sm) 0")
      }
      // The toolbar reads as a floating glass bar: its fill + backdrop come
      // from the shared `bar` material (composed in `Toolbar`); this rule
      // adds the padding and radius that give the bar its shape.
      rule(".swui-toolbar") {
        .padding("var(--swui-space-sm) var(--swui-space-md)")
          .borderRadius("var(--swui-radius-large)")
      }
      rule(".swui-label-style-titleOnly .swui-label-icon") {
        .display("none")
      }
      rule(".swui-label-style-iconOnly .swui-label-title") {
        .display("none")
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
        .padding("var(--swui-space-sm)")
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
      rule(".swui-text-muted") {
        .color("var(--swui-text-muted)")
      }
      rule(".swui-inline-code") {
        .display("inline-block")
          .padding("0 0.35em")
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
          .padding("var(--swui-space-md)")
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
          .padding("var(--swui-space-md) 0")
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
          .columnGap("var(--swui-space-md)")
          .padding("0 var(--swui-space-md)")
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
          .gap("var(--swui-space-sm)")
          .border("1px solid transparent")
          .borderRadius("var(--swui-button-radius)")
          .minHeight("var(--swui-control-regular-height)")
          .padding("0 var(--swui-space-lg)")
          .font("inherit")
          .cursor("pointer")
          .textDecoration("none")
          .whiteSpace("nowrap")
          .minWidth("max-content")
          .lineHeight("1")
          .boxSizing("border-box")
          .transition(
            "background var(--swui-motion-quick), border-color var(--swui-motion-quick), opacity var(--swui-motion-quick)"
          )
      }
      rule(".swui-control-mini") {
        .minHeight("var(--swui-control-mini-height)")
          .paddingInline("var(--swui-space-sm)")
          .fontSize("12px")
      }
      rule(".swui-control-small") {
        .minHeight("var(--swui-control-small-height)")
          .paddingInline("var(--swui-space-md)")
          .fontSize("14px")
      }
      rule(".swui-control-regular") {
        .minHeight("var(--swui-control-regular-height)")
      }
      rule(".swui-control-large") {
        .minHeight("var(--swui-control-large-height)")
          .paddingInline("var(--swui-space-xl)")
          .fontSize("17px")
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
          .paddingInline("0")
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
          .gap("var(--swui-space-sm)")
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
          .padding("var(--swui-badge-padding)")
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
      rule(".swui-link") {
        .color("var(--swui-accent)")
      }
      rule(".swui-navigation-stack") {
        .display("grid")
          .gap("var(--swui-navigation-gap)")
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
          .gap("var(--swui-space-md)")
          .boxSizing("border-box")
      }
      rule(".swui-section-footer") {
        .fontSize("13px")
      }
      rule(".swui-list") {
        .display("grid")
          .boxSizing("border-box")
      }
      rule(".swui-list-row") {
        .display("flex")
          .alignItems("center")
          .gap("var(--swui-space-sm)")
          .boxSizing("border-box")
      }
      rule(".swui-list-row .swui-text") {
        .lineHeight("1.35")
      }
      rule(".swui-list-row > .swui-text:first-child") {
        .fontWeight("500")
      }
      rule(".swui-list-row .swui-text-muted") {
        .fontSize("13px")
      }
      rule(".swui-field") {
        .display("grid")
          .gap("var(--swui-space-xs)")
          .color("var(--swui-text)")
      }
      rule(".swui-picker-field") {
        .display("grid")
          .gap("var(--swui-space-xs)")
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
          .padding("var(--swui-field-padding)")
          .boxSizing("border-box")
          .color("var(--swui-text)")
          .font("inherit")
      }
      rule(".swui-slider") {
        .accentColor("var(--swui-tint, var(--swui-accent))")
          .minWidth("160px")
      }
      rule(".swui-toggle") {
        .display("inline-flex")
          .alignItems("center")
          .gap("var(--swui-space-sm)")
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
          .top("var(--swui-toggle-thumb-offset)")
          .borderRadius("999px")
          .background("var(--swui-text-muted)")
          .transition("transform var(--swui-motion-quick), background var(--swui-motion-quick)")
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
      rule(".swui-symbol") {
        .fontFamily("var(--swui-mono-font-family)")
          .fontSize("0.85em")
          .lineHeight("1")
      }

      // MARK: ProgressView
      // Container stacks an optional label over the bar/spinner.
      rule(".swui-progress") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-xs)")
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
        .background("var(--swui-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-progress-bar::-moz-progress-bar") {
        .background("var(--swui-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      // Indeterminate spinner; `@keyframes swui-spin` is appended raw in
      // `css(for:)` because keyframes are not expressible as a flat rule.
      rule(".swui-progress-spinner") {
        .width("20px")
          .height("20px")
          .borderRadius("999px")
          .border("2px solid color-mix(in srgb, var(--swui-text-muted) 30%, transparent)")
          .borderTopColor("var(--swui-tint, var(--swui-accent))")
          .animation("swui-spin 0.7s linear infinite")
          .boxSizing("border-box")
      }

      // MARK: Gauge
      rule(".swui-gauge") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-xs)")
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
        .background("var(--swui-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-webkit-meter-suboptimum-value") {
        .background("var(--swui-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-webkit-meter-even-less-good-value") {
        .background("var(--swui-tint, var(--swui-accent))")
          .borderRadius("var(--swui-radius-pill)")
      }
      rule(".swui-gauge-meter::-moz-meter-bar") {
        .background("var(--swui-tint, var(--swui-accent))")
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
          .gap("var(--swui-space-sm)")
          .padding("var(--swui-space-md)")
          .cursor("pointer")
          .fontWeight("600")
          .color("var(--swui-text)")
          .userSelect("none")
          .custom("list-style", "none")
      }
      rule(".swui-disclosure-summary::-webkit-details-marker") {
        .display("none")
      }
      rule(".swui-disclosure-content") {
        .padding("0 var(--swui-space-md) var(--swui-space-md)")
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
          .padding("var(--swui-field-padding)")
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
          .gap("var(--swui-space-sm)")
          .cursor("pointer")
      }
      // No material on the swatch — it must show the chosen color verbatim.
      rule(".swui-color-picker-input") {
        .appearance("none")
          .custom("-webkit-appearance", "none")
          .width("44px")
          .height("28px")
          .padding("0")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-radius-small)")
          .background("transparent")
          .cursor("pointer")
          .boxSizing("border-box")
      }
      rule(".swui-color-picker-input::-webkit-color-swatch-wrapper") {
        .padding("0")
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
          .gap("2px")
          .padding("3px")
          .minHeight("var(--swui-control-regular-height)")
          .borderRadius("var(--swui-button-radius)")
          .boxSizing("border-box")
          .overflow("hidden")
      }
      rule(".swui-picker-inline") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-xs)")
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
          .padding("0 12px")
          .borderRadius("calc(var(--swui-button-radius) - 3px)")
          .textAlign("center")
          .lineHeight("1")
          .custom("white-space", "nowrap")
          .transition("background var(--swui-motion-quick), color var(--swui-motion-quick)")
      }
      rule(".swui-picker-segmented .swui-picker-segment-input:checked ~ .swui-picker-segment-label")
      {
        .background("var(--swui-accent)")
          .color("var(--swui-accent-text)")
      }
      rule(".swui-picker-inline .swui-picker-segment-label") {
        .justifyContent("flex-start")
          .gap("var(--swui-space-sm)")
          .padding("var(--swui-space-xs) 0")
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
          .gap("var(--swui-space-xs)")
          .padding("var(--swui-field-padding)")
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
          .top("calc(100% + var(--swui-space-xs))")
          .insetInlineStart("0")
          .minWidth("180px")
          .display("flex")
          .flexDirection("column")
          .gap("2px")
          .padding("var(--swui-space-xs)")
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
          .gap("var(--swui-space-xs)")
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
          .gap("var(--swui-space-xs)")
          .padding("var(--swui-field-padding)")
          .borderRadius("var(--swui-radius-pill)")
          .cursor("pointer")
          .userSelect("none")
          .color("var(--swui-text)")
          .transition("background var(--swui-motion-quick), color var(--swui-motion-quick)")
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
          .paddingBlockStart("var(--swui-space-sm)")
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
          .gap("var(--swui-space-sm)")
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
          .padding("var(--swui-field-padding)")
          .color("var(--swui-text)")
          .font("inherit")
      }
      rule(".swui-search-suggestion-host, .swui-search-scoped") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-sm)")
      }
      rule(".swui-search-suggestions") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-xs)")
      }
      rule(".swui-search-tokenized") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-sm)")
      }
      rule(".swui-search-tokens") {
        .display("flex")
          .gap("var(--swui-space-xs)")
          .flexWrap("wrap")
      }
      rule(".swui-search-token") {
        .display("inline-flex")
          .alignItems("center")
          .gap("var(--swui-space-xs)")
          .border("var(--swui-field-border)")
          .borderRadius("var(--swui-radius-pill)")
          .background("var(--swui-surface-raised)")
          .color("var(--swui-text)")
          .padding("2px var(--swui-space-sm)")
          .font("inherit")
          .lineHeight("var(--swui-line-height-tight)")
          .cursor("pointer")
      }
      rule(".swui-search-scopes") {
        .display("flex")
          .gap("var(--swui-space-xs)")
          .flexWrap("wrap")
      }
      rule(".swui-search-scope") {
        .display("inline-flex")
          .alignItems("center")
          .gap("var(--swui-space-xs)")
      }
      // MARK: Presentation (alert / confirmationDialog / sheet / popover)
      // The shared `<dialog>` overlay composes the material primitive; this
      // rule keeps the border, radius, drop shadow, sizing, and modal layout.
      // A `<dialog>` without `open` is `display: none` by UA default, so the
      // overlay costs no layout while hidden.
      rule(".swui-presentation") {
        .margin("auto")
          .padding("0")
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
          .top("0")
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
          .custom("backdrop-filter", "blur(2px)")
      }
      rule(".swui-presentation-surface") {
        .display("flex")
          .flexDirection("column")
          .gap("var(--swui-space-md)")
          .padding("var(--swui-space-lg)")
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
          .gap("var(--swui-space-sm)")
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
        .top("auto")
      }
      // The popover reads as a compact panel. True source anchoring needs the
      // CSS anchor positioning API; until then it presents centered.
      rule(".swui-presentation-popover") {
        .maxWidth("min(92vw, 20rem)")
      }
    }
  }

  private static let designContractCSS = """

  input,
  button,
  select,
  textarea {
    font-family: inherit;
  }

  .swui-root {
    min-height: auto;
    color: var(--swui-text);
    font-family: var(--swui-font-family);
  }

  .swui-vstack,
  .swui-lazy-vstack {
    display: flex;
    flex-direction: column;
    align-items: stretch;
  }

  .swui-hstack,
  .swui-lazy-hstack,
  .swui-toolbar {
    display: flex;
    flex-direction: row;
    align-items: center;
  }

  .swui-spacer {
    flex: 1 1 auto;
  }

  .swui-divider {
    width: 100%;
    height: 1px;
    border: 0;
    background: var(--swui-border);
  }

  .swui-hstack > .swui-divider,
  .swui-lazy-hstack > .swui-divider,
  .swui-toolbar > .swui-divider {
    width: 1px;
    height: auto;
    align-self: stretch;
  }

  .swui-heading {
    margin: 0;
    color: var(--swui-text);
    font-weight: 600;
    line-height: 1.2;
    letter-spacing: 0;
  }

  .swui-heading-page {
    font-size: 30px;
    font-weight: 680;
  }

  .swui-heading-section {
    font-size: 22px;
  }

  .swui-heading-subsection {
    font-size: 17px;
  }

  .swui-text {
    margin: 0;
    color: var(--swui-text);
    font-size: 14px;
    line-height: 1.5;
  }

  .swui-text-muted {
    color: var(--swui-text-muted);
  }

  .swui-inline-code {
    display: inline-block;
    padding: 1px 0.4em;
    border: 0;
    border-radius: var(--swui-radius-small);
    background: color-mix(in srgb, var(--swui-surface-raised) 86%, var(--swui-accent));
    font-family: var(--swui-mono-font-family);
    font-size: 0.9em;
    line-height: 1.5;
  }

  .swui-code-block {
    min-width: 360px;
    max-width: 560px;
    margin: 0;
    overflow: auto;
    padding: 14px 0;
    border: 1px solid var(--swui-border);
    border-radius: 12px;
    background: color-mix(in srgb, var(--swui-surface-raised) 92%, var(--swui-accent));
    color: var(--swui-text);
    font-family: var(--swui-mono-font-family);
    font-size: 13px;
    line-height: 1.65;
    box-sizing: border-box;
  }

  .swui-code-line {
    display: grid;
    grid-template-columns: minmax(2.5ch, auto) 1fr;
    column-gap: 16px;
    padding: 0 18px;
    white-space: pre;
  }

  .swui-code-line-plain {
    display: block;
    padding: 0 18px;
    white-space: pre;
  }

  .swui-code-line-number {
    opacity: 0.4;
    color: var(--swui-text);
    text-align: right;
    user-select: none;
  }

  .swui-code-line-content {
    white-space: pre;
    font-family: var(--swui-mono-font-family);
  }

  .swui-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    min-width: max-content;
    border: 1px solid transparent;
    border-radius: var(--swui-button-radius);
    padding: 7px 14px;
    box-sizing: border-box;
    color: var(--swui-text);
    font: inherit;
    font-size: 14px;
    font-weight: 500;
    line-height: 1;
    white-space: nowrap;
    text-decoration: none;
    cursor: pointer;
  }

  .swui-button.swui-control-mini {
    min-height: 0;
    padding: 4px 9px;
    border-radius: var(--swui-radius-small);
    font-size: 11px;
  }

  .swui-button.swui-control-small {
    min-height: 0;
    padding: 5px 11px;
    font-size: 12px;
  }

  .swui-button.swui-control-regular {
    min-height: 0;
    padding: 7px 14px;
    font-size: 14px;
  }

  .swui-button.swui-control-large {
    min-height: 0;
    padding: 10px 20px;
    font-size: 16px;
  }

  .swui-button-primary {
    background: var(--swui-control-tint, var(--swui-button-primary-background));
    color: var(--swui-button-primary-foreground);
  }

  .swui-button-secondary {
    background: var(--swui-button-secondary-background);
    color: var(--swui-button-secondary-foreground);
    border-color: var(--swui-button-secondary-border);
  }

  .swui-button-plain {
    background: transparent;
    color: var(--swui-control-tint, var(--swui-button-plain-foreground));
    border-color: transparent;
  }

  .swui-button-glass {
    background: color-mix(in srgb, var(--swui-surface) 55%, transparent);
    color: var(--swui-text);
    border-color: var(--swui-border);
    backdrop-filter: blur(10px);
  }

  .swui-button-glass-prominent {
    background: var(--swui-control-tint, var(--swui-accent));
    color: var(--swui-accent-text);
    border-color: transparent;
    backdrop-filter: blur(10px);
  }

  .swui-control-disabled,
  .swui-button:disabled,
  .swui-text-field:disabled,
  .swui-picker:disabled,
  .swui-slider:disabled {
    opacity: var(--swui-control-disabled-opacity);
    cursor: default;
    pointer-events: none;
  }

  .swui-group-box {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    background: var(--swui-surface-raised);
    border: var(--swui-container-border);
    border-radius: var(--swui-container-radius);
    box-shadow: var(--swui-container-shadow);
    box-sizing: border-box;
  }

  .swui-group-box-title {
    margin: 0 0 var(--swui-space-sm) 0;
  }

  .swui-badge {
    display: inline-flex;
    align-items: center;
    width: fit-content;
    gap: 6px;
    padding: var(--swui-badge-padding);
    border: var(--swui-badge-border);
    border-radius: var(--swui-badge-radius);
    background: var(--swui-badge-background);
    color: var(--swui-badge-foreground);
    font-size: 12.5px;
    font-weight: 600;
    line-height: 1.4;
  }

  .swui-list {
    display: flex;
    flex-direction: column;
    min-width: 260px;
    overflow: hidden;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: 12px;
    box-sizing: border-box;
  }

  .swui-list-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 9px 13px;
    border-bottom: 1px solid var(--swui-border);
    box-sizing: border-box;
  }

  .swui-list-row:last-child {
    border-bottom: 0;
  }

  .swui-list-row .swui-text {
    line-height: 1.35;
  }

  .swui-list-row > .swui-text:first-child {
    font-weight: 500;
  }

  .swui-list-row .swui-text-muted {
    font-size: 13px;
  }

  .swui-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-width: 280px;
    box-sizing: border-box;
  }

  .swui-section-header {
    margin: 0;
    padding: 10px 14px 6px;
    background: color-mix(in srgb, var(--swui-text-muted) 7%, transparent);
    color: var(--swui-text-muted);
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
  }

  .swui-section-footer,
  .swui-section-footer-row {
    color: var(--swui-text-muted);
    font-size: 12.5px;
    line-height: 1.45;
  }

  .swui-field,
  .swui-picker-field {
    display: flex;
    flex-direction: column;
    gap: 6px;
    color: var(--swui-text);
  }

  .swui-field-label,
  .swui-toggle-label {
    color: var(--swui-text-muted);
    font-size: 12.5px;
    font-weight: 600;
  }

  .swui-text-field,
  .swui-text-editor,
  .swui-picker,
  .swui-date-picker {
    min-height: 0;
    min-width: 220px;
    padding: var(--swui-field-padding);
    border: var(--swui-field-border);
    border-radius: var(--swui-field-radius);
    background: var(--swui-field-background);
    color: var(--swui-text);
    font: inherit;
    font-size: 14px;
    outline: none;
    box-sizing: border-box;
  }

  .swui-text-field:focus,
  .swui-text-editor:focus {
    border-color: var(--swui-accent);
  }

  .swui-text-editor {
    min-height: 80px;
    width: 100%;
    line-height: 1.5;
    resize: vertical;
  }

  .swui-slider {
    width: 220px;
    height: 4px;
    accent-color: var(--swui-control-tint, var(--swui-accent));
  }

  .swui-stepper {
    display: inline-flex;
    align-items: center;
    width: fit-content;
    max-width: 100%;
    min-height: 0;
    padding: 0;
    overflow: hidden;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: var(--swui-button-radius);
    color: var(--swui-text);
    box-sizing: border-box;
  }

  .swui-stepper-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 31px;
    min-height: 0;
    padding: 0;
    border: 0;
    background: transparent;
    color: var(--swui-control-tint, var(--swui-accent));
    font: inherit;
    font-size: 16px;
    font-weight: 500;
    line-height: 1;
    cursor: pointer;
  }

  .swui-stepper-value,
  .swui-stepper .val {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 42px;
    height: 31px;
    border-left: 1px solid var(--swui-border);
    border-right: 1px solid var(--swui-border);
    color: var(--swui-text);
    font-variant-numeric: tabular-nums;
    text-align: center;
  }

  .swui-toggle {
    display: inline-flex;
    align-items: center;
    gap: 9px;
    color: var(--swui-text);
    font-size: 14px;
    cursor: pointer;
  }

  .swui-toggle-control {
    width: 38px;
    height: 23px;
    border: 0;
    border-radius: var(--swui-radius-pill);
    background: color-mix(in srgb, var(--swui-text-muted) 45%, transparent);
    position: relative;
    flex: none;
    transition: background var(--swui-motion-quick);
  }

  .swui-toggle-control::after {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 19px;
    height: 19px;
    border-radius: 50%;
    background: #fff;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
    content: "";
    transition: transform var(--swui-motion-quick);
  }

  .swui-toggle-input:checked + .swui-toggle-control {
    background: var(--swui-accent);
  }

  .swui-toggle-input:checked + .swui-toggle-control::after {
    transform: translateX(15px);
    background: #fff;
  }

  .swui-picker-segmented {
    display: inline-flex;
    gap: 2px;
    min-height: 0;
    padding: 2px;
    overflow: visible;
    background: color-mix(in srgb, var(--swui-text-muted) 14%, transparent);
    border-radius: var(--swui-button-radius);
  }

  .swui-picker-segmented .swui-picker-segment {
    flex: 0 0 auto;
    min-width: max-content;
    color: var(--swui-text);
  }

  .swui-picker-segmented .swui-picker-segment-label {
    min-height: 0;
    padding: 6px 14px;
    border-radius: calc(var(--swui-button-radius) - 2px);
    color: var(--swui-text);
    font-size: 13px;
    line-height: 1;
    white-space: nowrap;
  }

  .swui-picker-segmented .swui-picker-segment-input:checked ~ .swui-picker-segment-label {
    background: var(--swui-surface-raised);
    color: var(--swui-text);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.18);
    font-weight: 600;
  }

  .swui-label {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    color: var(--swui-text);
    font-size: 14px;
  }

  .swui-label-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    color: var(--swui-accent);
  }

  .swui-link,
  .swui-navigation-link {
    color: var(--swui-accent);
    text-decoration: none;
  }

  .swui-navigation-stack {
    display: flex;
    flex-direction: column;
    min-width: 260px;
    overflow: hidden;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: 12px;
  }

  .swui-navigation-bar {
    padding: 12px 14px 10px;
    border-bottom: 1px solid var(--swui-border);
    color: var(--swui-text);
    font-size: 18px;
    font-weight: 680;
    letter-spacing: 0;
  }

  .swui-navigation-content {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--swui-space-sm);
    padding: 12px 14px;
  }

  .swui-toolbar {
    min-width: 260px;
    gap: 10px;
    padding: 9px 12px;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: 12px;
  }

  .swui-scroll-view {
    min-width: 240px;
    max-height: 150px;
    overflow: auto;
    padding: 10px;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: 12px;
  }

  .swui-progress {
    display: flex;
    flex-direction: column;
    min-width: 220px;
    gap: 6px;
  }

  .swui-progress-bar {
    width: 220px;
    height: 7px;
    border: 0;
    border-radius: var(--swui-radius-pill);
    overflow: hidden;
    background: color-mix(in srgb, var(--swui-text-muted) 24%, transparent);
  }

  .swui-progress-spinner {
    width: 26px;
    height: 26px;
    border-width: 3px;
  }

  .swui-gauge {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }

  .swui-disclosure-group {
    min-width: 260px;
    overflow: hidden;
    background: var(--swui-surface-raised);
    border: 1px solid var(--swui-border);
    border-radius: 12px;
  }

  .swui-disclosure-summary {
    padding: 11px 13px;
    gap: 10px;
  }

  .swui-disclosure-content {
    padding: 0 14px 14px;
  }

  .swui-searchable {
    display: flex;
    flex-direction: column;
    gap: var(--swui-space-sm);
  }

  .swui-search-field {
    width: 100%;
    min-height: 0;
    padding: 8px 12px;
    border: 1px solid var(--swui-border);
    border-radius: var(--swui-button-radius);
    background: var(--swui-surface);
    color: var(--swui-text);
    font: inherit;
    font-size: 14px;
  }

  .swui-search-suggestion-host,
  .swui-search-scoped {
    display: flex;
    flex-direction: column;
    gap: var(--swui-space-sm);
  }

  .swui-search-suggestions {
    display: flex;
    flex-direction: column;
    gap: var(--swui-space-xs);
  }

  .swui-search-tokenized {
    display: flex;
    flex-direction: column;
    gap: var(--swui-space-sm);
  }

  .swui-search-tokens {
    display: flex;
    gap: var(--swui-space-xs);
    flex-wrap: wrap;
  }

  .swui-search-token {
    display: inline-flex;
    align-items: center;
    gap: var(--swui-space-xs);
    border: var(--swui-field-border);
    border-radius: var(--swui-radius-pill);
    background: var(--swui-surface-raised);
    color: var(--swui-text);
    padding: 2px var(--swui-space-sm);
    font: inherit;
    line-height: var(--swui-line-height-tight);
    cursor: pointer;
  }

  .swui-search-scopes {
    display: flex;
    gap: var(--swui-space-xs);
    flex-wrap: wrap;
  }

  .swui-search-scope {
    display: inline-flex;
    align-items: center;
    gap: var(--swui-space-xs);
  }
  """

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
      rule(
        """
        .swui-material,
        .swui-glass
        """
      ) {
        .position("relative")
          .isolation("isolate")
          .custom("--swui-material-level-opacity", "var(--swui-material-opacity)")
          .background(
            "color-mix(in srgb, var(--swui-material-tint) calc(var(--swui-material-level-opacity) * 100%), transparent)"
          )
          .backdropFilter(
            "blur(var(--swui-material-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
          )
          .custom(
            "-webkit-backdrop-filter",
            "blur(var(--swui-material-blur)) saturate(var(--swui-material-saturate)) brightness(calc(var(--swui-material-brightness) * var(--swui-material-interactive, 1)))"
          )
      }
      // One overlay carries both the SVG displacement refraction (a second
      // backdrop-filter pass) and the specular rim (inset shadow), leaving
      // `::after` free for component pseudo-elements (e.g. the toggle
      // thumb). On Safari the `url()` backdrop-filter is ignored and only
      // the base blur remains — a documented degradation, not a silent one.
      rule(
        """
        .swui-material::before,
        .swui-glass::before
        """
      ) {
        .content("\"\"")
          .position("absolute")
          .inset("0")
          .zIndex("-1")
          .borderRadius("inherit")
          .backdropFilter("var(--swui-material-refraction)")
          .custom("-webkit-backdrop-filter", "var(--swui-material-refraction)")
          .boxShadow("var(--swui-material-rim)")
          .pointerEvents("none")
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

  /// Opaque fallback applied where translucency is unavailable or unwanted.
  /// Appended raw because `@supports`/`@media` blocks are not expressible as a
  /// flat `CSSRule`. Both the unsupported-`backdrop-filter` path and the
  /// reduced-transparency path drop to the solid fill and hide the overlay —
  /// an explicit, designed recipe rather than a silent fallback.
  private static let materialFallbackCSS = """
    @supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
      .swui-material,
      .swui-glass {
        background: var(--swui-material-solid-fill);
      }
      .swui-material::before,
      .swui-glass::before {
        display: none;
      }
    }
    @media (prefers-reduced-transparency: reduce) {
      .swui-material,
      .swui-glass {
        background: var(--swui-material-solid-fill);
      }
      .swui-material::before,
      .swui-glass::before {
        display: none;
      }
    }
    """

  /// Rotation keyframes for the indeterminate `ProgressView` spinner. Appended
  /// raw because `@keyframes` is not expressible as a flat `CSSRule`.
  private static let progressSpinnerKeyframes = """
    @keyframes swui-spin {
      to { transform: rotate(360deg); }
    }
    """
}
