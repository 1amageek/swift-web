import SwiftHTML

/// The Storyboard's chrome styling. Authored as a typed `Stylesheet` (the same
/// model the core `ThemeStylesheet` uses) so the rules are the single source of
/// truth rather than a raw CSS blob. Only the responsive `@media` block stays
/// raw, because the flat `CSSRule` model cannot express at-rules.
struct StoryboardStylesheet: Component {
    var body: some HTML {
        style {
            rawHTML(Self.cssText)
        }
    }

    static var cssText: String {
        stylesheet.cssText
    }

    private static var stylesheet: Stylesheet {
        Stylesheet {
      rule("html") {
        .scrollBehavior("smooth")
      }
      rule("body") {
        .margin("0")
      }
      rule(".storyboard-page") {
        .custom("--bg", "var(--swui-surface)")
          .custom("--bg-sub", "color-mix(in srgb, var(--swui-text-muted) 8%, var(--swui-surface))")
          .custom("--seg-active", "var(--swui-surface-raised)")
          .custom("--ui-text", "var(--swui-text)")
          .custom("--ui-text-2", "var(--swui-text-muted)")
          .custom("--ui-border", "var(--swui-border)")
          .custom("--ui-accent", "var(--swui-accent)")
          .custom("--ui-accent-soft", "color-mix(in srgb, var(--swui-accent) 10%, transparent)")
          .custom("--code-bg", "color-mix(in srgb, var(--swui-text-muted) 7%, var(--swui-surface))")
          .custom("--code-text", "var(--swui-text)")
          .custom("--shadow", "0 1px 3px rgba(0,0,0,.06), 0 12px 32px rgba(0,0,0,.07)")
          .height("100vh")
          .minHeight("100vh")
          .overflow("hidden")
          .background("var(--bg)")
          .color("var(--ui-text)")
          .fontFamily("-apple-system, BlinkMacSystemFont, \"SF Pro Text\", \"SF Pro Display\", system-ui, sans-serif")
          .custom("-webkit-font-smoothing", "antialiased")
      }
      rule(".storyboard-page, .storyboard-page *") {
        .boxSizing("border-box")
      }
      rule(".storyboard-page a") {
        .color("inherit")
      }
      rule(".storyboard-shell") {
        .height("100%")
          .minHeight("0")
      }
      rule(".storyboard-landmark") {
        .display("contents")
      }
      rule(".storyboard-topbar") {
        .flex("none")
          .zIndex("40")
          .minHeight("54px")
          .height("54px")
          .borderBottom("1px solid var(--ui-border)")
          .padding("0 18px")
          .gap("14px")
          .background("var(--bg)")
          .alignItems("center !important")
          .flexWrap("nowrap !important")
      }
      rule(".storyboard-page .storyboard-topbar-title") {
        .width("226px")
          .maxWidth("226px")
          .flex("0 0 226px !important")
          .alignItems("center !important")
          .gap("9px !important")
          .minWidth("0")
      }
      rule(".storyboard-mark") {
        .width("26px")
          .height("26px")
          .borderRadius("7px")
          .background("linear-gradient(160deg, #65a8ff, #1769e0)")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .color("#fff")
          .fontWeight("700")
          .fontSize("14px")
          .boxShadow("0 2px 6px rgba(23,105,224,.4)")
          .flex("none")
      }
      rule(".storyboard-product-title") {
        .fontSize("15px")
          .fontWeight("640")
          .letterSpacing("0")
          .whiteSpace("nowrap")
      }
      rule(".storyboard-product-badge") {
        .fontSize("11px")
          .color("var(--ui-text-2)")
          .border("1px solid var(--ui-border)")
          .borderRadius("5px")
          .padding("1px 5px")
          .whiteSpace("nowrap")
      }
      rule(".storyboard-search") {
        .flex("1 1 280px")
          .maxWidth("280px")
          .display("flex")
          .alignItems("center")
          .gap("8px")
          .minWidth("180px")
          .background("var(--bg-sub)")
          .borderRadius("9px")
          .padding("7px 12px")
          .color("var(--ui-text-2)")
          .fontSize("13px")
          .lineHeight("1")
      }
      rule(".storyboard-search-icon") {
        .opacity(".6")
      }
      rule(".storyboard-search span:not(.storyboard-search-icon):not(.storyboard-search-shortcut)") {
        .whiteSpace("nowrap")
      }
      rule(".storyboard-search-shortcut") {
        .marginLeft("auto")
          .fontSize("11px")
          .border("1px solid var(--ui-border)")
          .borderRadius("5px")
          .padding("1px 5px")
          .whiteSpace("nowrap")
      }
      rule(".storyboard-topbar-actions") {
        .marginLeft("auto")
          .alignItems("center !important")
          .gap("16px !important")
          .flexWrap("nowrap !important")
          .minWidth("0")
      }
      rule(".storyboard-topbar-link") {
        .color("var(--ui-text)")
          .fontSize("13.5px")
          .fontWeight("500")
          .textDecoration("none")
          .whiteSpace("nowrap")
      }
      rule(".storyboard-topbar-link.is-muted") {
        .color("var(--ui-text-2)")
      }
      rule(".storyboard-theme-switcher, .storyboard-control-segments") {
        .display("inline-flex")
          .gap("2px")
          .padding("3px")
          .borderRadius("8px")
          .background("var(--bg-sub)")
          .border("1px solid var(--ui-border)")
          .flex("none")
      }
      rule(".storyboard-page .storyboard-theme-button, .storyboard-page .storyboard-control-segment, .storyboard-page .storyboard-control-toggle") {
        .minHeight("30px")
          .height("30px")
          .border("0")
          .borderRadius("6px")
          .padding("0 11px")
          .background("transparent")
          .color("var(--ui-text)")
          .fontSize("13px")
          .fontWeight("500")
          .lineHeight("1")
          .whiteSpace("nowrap")
          .boxShadow("none")
      }
      rule(".storyboard-page .storyboard-theme-button.is-selected, .storyboard-page .storyboard-control-segment.is-selected, .storyboard-page .storyboard-control-toggle.is-selected") {
        .background("var(--seg-active)")
          .boxShadow("0 1px 2px rgba(0,0,0,.14)")
          .color("var(--ui-text)")
      }
      rule(".storyboard-main") {
        .flex("1 1 auto")
          .minHeight("0")
          .overflow("hidden")
          .flexWrap("nowrap !important")
          .alignItems("stretch !important")
      }
      rule(".storyboard-page .storyboard-sidebar") {
        .flex("0 0 226px !important")
          .width("226px !important")
          .maxWidth("226px")
          .height("100%")
          .overflowY("auto")
          .padding("14px 12px")
          .background("var(--bg)")
          .borderRight("1px solid var(--ui-border)")
          .gap("14px !important")
      }
      rule(".storyboard-sidebar-section") {
        .marginBottom("0")
      }
      rule(".storyboard-sidebar-section-title") {
        .margin("0")
          .textTransform("uppercase")
          .letterSpacing(".05em")
          .fontSize("11px")
          .fontWeight("700")
          .lineHeight("1.2")
          .opacity(".7")
          .padding("6px 10px")
          .color("var(--ui-text-2)")
      }
      rule(".storyboard-sidebar-section-items") {
        .gap("2px !important")
      }
      rule(".storyboard-sidebar-link") {
        .display("block")
          .width("100%")
          .minHeight("31px")
          .padding("6px 10px")
          .borderRadius("7px")
          .color("var(--ui-text-2)")
          .textDecoration("none")
          .whiteSpace("nowrap")
          .fontSize("13.5px")
          .fontWeight("500")
          .lineHeight("1.35")
          .cursor("pointer")
      }
      rule(".storyboard-sidebar-link:hover") {
        .background("color-mix(in srgb, var(--ui-text) 6%, transparent)")
          .color("var(--ui-text)")
      }
      rule(".storyboard-sidebar-link.is-selected") {
        .background("var(--ui-accent-soft)")
          .color("var(--ui-accent)")
          .fontWeight("600")
      }
      rule(".storyboard-page .storyboard-detail") {
        .flex("1 1 0 !important")
          .width("auto !important")
          .minWidth("0")
          .height("100%")
          .overflowY("auto")
          .display("block")
          .padding("22px 30px")
      }
      rule(".storyboard-detail-content") {
        .width("min(100%, 760px)")
      }
      rule(".storyboard-page .storyboard-inspector") {
        .flex("0 0 184px !important")
          .width("184px !important")
          .maxWidth("184px")
          .height("100%")
          .overflowY("auto")
          .padding("22px 18px")
          .borderLeft("1px solid var(--ui-border)")
          .background("var(--bg)")
      }
      rule(".storyboard-breadcrumb") {
        .marginBottom("8px")
          .fontSize("12px")
          .color("var(--ui-text-2)")
          .lineHeight("1.4")
      }
      rule(".storyboard-breadcrumb-separator") {
        .opacity(".5")
          .margin("0 5px")
      }
      rule(".storyboard-breadcrumb-current") {
        .color("var(--ui-text)")
      }
      rule(".storyboard-title") {
        .fontSize("25px")
          .fontWeight("680")
          .lineHeight("1.15")
          .letterSpacing("0")
          .margin("0 0 5px")
      }
      rule(".storyboard-description") {
        .fontSize("14px")
          .lineHeight("1.5")
          .color("var(--ui-text-2)")
          .margin("0 0 16px")
      }
      rule(".storyboard-section") {
        .marginTop("18px")
      }
      rule(".storyboard-section.bottom") {
        .marginBottom("10px")
      }
      rule(".storyboard-section-title") {
        .fontSize("12.5px")
          .fontWeight("640")
          .lineHeight("1.3")
          .margin("0 0 7px")
      }
      rule(".storyboard-section-title.tight") {
        .marginBottom("3px")
      }
      rule(".storyboard-section-title.related") {
        .marginBottom("9px")
      }
      rule(".storyboard-section-caption") {
        .margin("0 0 8px")
          .color("var(--ui-text-2)")
          .fontSize("12.5px")
          .lineHeight("1.5")
      }
      rule(".storyboard-preview-frame") {
        .overflow("hidden")
          .border("1px solid var(--ui-border)")
          .borderRadius("12px")
          .background("var(--bg)")
      }
      rule(".storyboard-preview-canvas") {
        .position("relative")
          .minHeight("168px")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .padding("24px")
          .background("var(--bg-sub)")
          .backgroundImage("radial-gradient(var(--ui-border) 1.1px, transparent 1.1px)")
          .backgroundSize("18px 18px")
      }
      rule(".storyboard-preview-root") {
        .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .flexWrap("wrap")
          .gap("14px")
          .width("100%")
      }
      rule(".storyboard-controls") {
        .borderTop("1px solid var(--ui-border)")
          .padding("11px 14px")
          .display("flex")
          .gap("18px")
          .alignItems("center")
          .flexWrap("wrap")
      }
      rule(".storyboard-control") {
        .display("flex")
          .alignItems("center")
          .gap("9px")
      }
      rule(".storyboard-control-label") {
        .fontSize("11px")
          .color("var(--ui-text-2)")
          .fontWeight("700")
          .textTransform("uppercase")
          .letterSpacing(".04em")
          .whiteSpace("nowrap")
      }
      rule(".storyboard-control-value") {
        .minWidth("34px")
          .color("var(--ui-text)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("12.5px")
      }
      rule(".storyboard-page .storyboard-control-text .swui-field-label") {
        .display("none")
      }
      rule(".storyboard-page .storyboard-control-text .swui-text-field") {
        .width("170px")
          .minWidth("170px")
          .background("var(--bg-sub)")
      }
      rule(".storyboard-page .storyboard-code-block") {
        .width("100%")
          .minWidth("0")
          .maxWidth("none")
          .margin("0")
          .border("1px solid var(--ui-border)")
          .borderRadius("12px")
          .overflow("auto")
          .background("var(--code-bg)")
          .color("var(--code-text)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("12.5px")
          .lineHeight("1.65")
          .padding("14px 0")
      }
      rule(".storyboard-page .storyboard-code-block.rendered") {
        .fontSize("12px")
          .lineHeight("1.6")
      }
      rule(".storyboard-page .storyboard-code-block .swui-code-line") {
        .display("grid")
          .gridTemplateColumns("minmax(2.5ch, auto) 1fr")
          .columnGap("16px")
          .padding("0 18px")
          .whiteSpace("pre")
      }
      rule(".storyboard-page .storyboard-code-block .swui-code-line-plain") {
        .display("block")
          .whiteSpace("pre-wrap")
          .wordBreak("break-word")
      }
      rule(".storyboard-page .storyboard-code-block .swui-code-line-number") {
        .textAlign("right")
          .userSelect("none")
          .opacity(".4")
      }
      rule(".storyboard-property-panel") {
        .overflow("hidden")
          .border("1px solid var(--ui-border)")
          .borderRadius("12px")
          .background("var(--bg)")
      }
      rule(".storyboard-property-row") {
        .borderBottom("1px solid var(--ui-border)")
          .padding("10px 14px")
      }
      rule(".storyboard-property-row:last-child") {
        .borderBottom("0")
      }
      rule(".storyboard-page .storyboard-property-name, .storyboard-page .storyboard-property-values") {
        .display("inline-block")
          .height("21px")
          .paddingBlock("0")
          .paddingInline("6px")
          .lineHeight("21px")
          .verticalAlign("middle")
          .letterSpacing("0")
          .fontKerning("normal")
          .fontFeatureSettings("\"kern\" 1, \"liga\" 0, \"calt\" 0")
          .fontVariantLigatures("none")
          .textRendering("geometricPrecision")
      }
      rule(".storyboard-page .storyboard-property-name") {
        .color("var(--ui-text)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("12.5px")
          .fontWeight("600")
      }
      rule(".storyboard-page .storyboard-property-values") {
        .color("var(--ui-accent)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("12.5px")
      }
      rule(".storyboard-related-grid") {
        .display("flex")
          .gap("12px")
          .flexWrap("wrap")
      }
      rule(".storyboard-related-link") {
        .flex("1 1 170px")
          .minWidth("170px")
          .border("1px solid var(--ui-border)")
          .borderRadius("10px")
          .padding("12px 14px")
          .color("var(--ui-text)")
          .textDecoration("none")
          .cursor("pointer")
      }
      rule(".storyboard-related-link p") {
        .marginTop("2px")
          .fontSize("12.5px")
          .lineHeight("1.4")
      }
      rule(".storyboard-inspector-title") {
        .marginBottom("12px")
          .color("var(--ui-text-2)")
          .fontSize("11px")
          .fontWeight("700")
          .lineHeight("1.2")
          .textTransform("uppercase")
          .letterSpacing(".05em")
          .opacity(".7")
      }
      rule(".storyboard-inspector-nav") {
        .gap("11px !important")
      }
      rule(".storyboard-inspector-link") {
        .display("block")
          .paddingLeft("10px")
          .color("var(--ui-text-2)")
          .fontSize("12.5px")
          .lineHeight("1.35")
          .textDecoration("none")
      }
      rule(".storyboard-inspector-link.is-selected") {
        .marginLeft("-12px")
          .borderLeft("2px solid var(--ui-accent)")
          .color("var(--ui-text)")
          .fontWeight("600")
      }
      rule(".storyboard-typography-preview") {
        .width("100%")
          .textAlign("center")
          .margin("0")
      }
      rule(".storyboard-centered-demo") {
        .alignItems("center !important")
          .justifyContent("center")
      }
      rule(".storyboard-grid-demo") {
        .width("480px")
          .maxWidth("82vw")
          .display("grid")
          .gridTemplateColumns("repeat(12, 1fr)")
          .gap("16px")
          .padding("0 16px")
      }
      rule(".storyboard-grid-pane") {
        .height("58px")
          .borderRadius("8px")
          .background("color-mix(in srgb, var(--ui-accent) 16%, transparent)")
          .border("1px solid color-mix(in srgb, var(--ui-accent) 32%, transparent)")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .color("var(--ui-accent)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("11px")
      }
      rule(".storyboard-grid-pane.span-8") {
        .gridColumn("span 8")
      }
      rule(".storyboard-grid-pane.span-4") {
        .gridColumn("span 4")
      }
      rule(".storyboard-spacing-demo") {
        .gap("34px !important")
          .alignItems("center !important")
          .flexWrap("wrap !important")
          .justifyContent("center")
      }
      rule(".storyboard-spacing-label") {
        .width("34px")
          .textAlign("right")
      }
      rule(".storyboard-spacing-bar") {
        .width("100%")
          .height("16px")
          .borderRadius("3px")
          .background("color-mix(in srgb, var(--ui-accent) 38%, transparent)")
      }
      rule(".storyboard-spacing-bar.is-active") {
        .background("var(--ui-accent)")
      }
      rule(".storyboard-spacing-base-label") {
        .color("var(--ui-accent)")
          .fontWeight("640")
      }
      rule(".storyboard-spacing-tile") {
        .display("grid")
          .gridTemplateColumns("repeat(4, 8px)")
          .gridAutoRows("8px")
          .gap("1px")
          .overflow("hidden")
          .border("1px solid var(--ui-border)")
          .borderRadius("4px")
          .background("var(--ui-border)")
      }
      rule(".storyboard-spacing-tile > div") {
        .background("color-mix(in srgb, var(--ui-accent) 12%, var(--bg))")
      }
      rule(".storyboard-spacing-grid-label") {
        .fontSize("12px")
      }
      rule(".storyboard-alignment-frame") {
        .width("420px")
          .maxWidth("80vw")
          .height("120px")
          .border("1.5px dashed var(--ui-border)")
          .borderRadius("10px")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .padding("0 14px")
      }
      rule(".storyboard-alignment-chip") {
        .padding("10px 18px")
          .borderRadius("8px")
          .background("var(--ui-accent)")
          .color("var(--swui-accent-text)")
          .fontSize("13px")
          .fontWeight("600")
      }
      rule(".storyboard-responsive-lattice") {
        .width("480px")
          .maxWidth("82vw")
          .height("38px")
          .display("grid")
          .gridTemplateColumns("repeat(12, 1fr)")
          .gap("22px")
          .padding("0 16px")
          .border("1px solid var(--ui-border)")
          .borderRadius("6px")
          .background("var(--bg)")
      }
      rule(".storyboard-responsive-lattice > div") {
        .background("color-mix(in srgb, var(--ui-accent) 13%, transparent)")
          .borderLeft("1px solid color-mix(in srgb, var(--ui-accent) 28%, transparent)")
          .borderRight("1px solid color-mix(in srgb, var(--ui-accent) 28%, transparent)")
      }
      rule(".storyboard-responsive-content") {
        .width("480px")
          .maxWidth("82vw")
          .padding("0 16px")
          .display("grid")
          .gridTemplateColumns("repeat(3, 1fr)")
          .gap("22px")
      }
      rule(".storyboard-responsive-content > div") {
        .height("62px")
          .borderRadius("8px")
          .background("color-mix(in srgb, var(--ui-accent) 17%, transparent)")
          .border("1px solid color-mix(in srgb, var(--ui-accent) 34%, transparent)")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .color("var(--ui-accent)")
          .fontFamily("var(--swui-mono-font-family)")
          .fontSize("11px")
      }
      rule(".storyboard-phone") {
        .position("relative")
          .width("188px")
          .height("300px")
          .overflow("hidden")
          .border("6px solid var(--ui-text)")
          .borderRadius("30px")
          .background("var(--swui-surface-raised)")
          .boxShadow("var(--shadow)")
      }
      rule(".storyboard-phone-notch") {
        .position("absolute")
          .top("0")
          .left("50%")
          .width("96px")
          .height("18px")
          .transform("translateX(-50%)")
          .borderRadius("0 0 12px 12px")
          .background("#000")
      }
      rule(".storyboard-phone-safe-area") {
        .position("absolute")
          .inset("30px 8px 18px")
          .border("1.5px dashed color-mix(in srgb, var(--ui-accent) 55%, transparent)")
          .borderRadius("8px")
          .background("color-mix(in srgb, var(--ui-accent) 9%, transparent)")
          .display("flex")
          .alignItems("center")
          .justifyContent("center")
          .color("var(--ui-accent)")
          .fontSize("11px")
          .fontWeight("640")
      }
      rule(".storyboard-phone-home") {
        .position("absolute")
          .left("50%")
          .bottom("7px")
          .width("90px")
          .height("4px")
          .transform("translateX(-50%)")
          .borderRadius("2px")
          .background("var(--ui-text-2)")
          .opacity(".6")
      }
      rule(".storyboard-color-swatch") {
        .width("150px")
          .height("104px")
          .background("#007aff")
      }
      rule(".storyboard-groupbox-demo") {
        .maxWidth("280px")
          .padding("13px")
      }
      rule(".storyboard-divider-demo") {
        .width("min(100%, 320px)")
      }
      media("(max-width: 980px)") {
        rule(".storyboard-topbar") {
          .height("auto")
            .minHeight("54px")
            .padding("10px 14px")
            .flexWrap("wrap !important")
        }
        rule(".storyboard-page .storyboard-topbar-title") {
          .width("auto")
            .maxWidth("none")
            .flex("1 1 220px !important")
        }
        rule(".storyboard-search") {
          .order("3")
            .flexBasis("100%")
            .maxWidth("none")
        }
        rule(".storyboard-topbar-actions") {
          .marginLeft("0")
        }
        rule(".storyboard-main") {
          .overflow("auto")
        }
        rule(".storyboard-sidebar,\n.storyboard-inspector") {
          .display("none")
        }
        rule(".storyboard-page .storyboard-detail") {
          .padding("22px 18px")
        }
      }
    }
    }
}
