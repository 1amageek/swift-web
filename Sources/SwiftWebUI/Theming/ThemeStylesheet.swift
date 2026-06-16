import SwiftHTML

enum ThemeStylesheet {
    static func stylesheet(for theme: Theme, designStyle: DesignStyle) -> Stylesheet {
        Stylesheet {
            baseStylesheet
            rule("[data-swift-web-ui-theme=\"\(cssAttributeString(theme.name))\"]") {
                theme.cssVariableStyle
            }
            rule("[data-swift-web-ui-design-style=\"\(cssAttributeString(designStyle.id))\"]") {
                designStyle.cssVariableStyle
            }
        }
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
            rule("""
            html,
            body
            """) {
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
            rule("""
            .swui-vstack,
            .swui-hstack,
            .swui-lazy-vstack,
            .swui-lazy-hstack,
            .swui-toolbar
            """) {
                .display("flex")
                .boxSizing("border-box")
            }
            rule("""
            .swui-vstack,
            .swui-lazy-vstack
            """) {
                .flexDirection("column")
            }
            rule("""
            .swui-hstack,
            .swui-lazy-hstack,
            .swui-toolbar
            """) {
                .flexDirection("row")
                .alignItems("center")
                .flexWrap("wrap")
            }
            rule("""
            .swui-lazy-vstack > *,
            .swui-lazy-hstack > *
            """) {
                .contentVisibility("auto")
                .containIntrinsicSize("var(--swui-lazy-intrinsic-size)")
            }
            rule("""
            .swui-lazy-vgrid,
            .swui-lazy-hgrid
            """) {
                .display("grid")
                .boxSizing("border-box")
            }
            rule("""
            .swui-lazy-vgrid > *,
            .swui-lazy-hgrid > *
            """) {
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
            rule(".swui-spacer") {
                .flex("1 1 auto")
            }
            rule(".swui-grid") {
                .display("grid")
                .alignItems("stretch")
                .justifyItems("stretch")
                .boxSizing("border-box")
            }
            rule(".swui-card") {
                .display("flex")
                .flexDirection("column")
                .alignItems("flex-start")
                .background("var(--swui-card-background)")
                .border("var(--swui-card-border)")
                .borderRadius("var(--swui-card-radius)")
                .boxSizing("border-box")
                .boxShadow("var(--swui-card-shadow)")
                .backdropFilter("var(--swui-card-backdrop-filter)")
            }
            // MARK: Sizing intent markers (parent-axis aware)
            // Horizontal fill under a column parent -> stretch the cross axis.
            rule("""
            .swui-vstack > .swui-fill-h,
            .swui-lazy-vstack > .swui-fill-h,
            .swui-card > .swui-fill-h,
            .swui-zstack > .swui-fill-h,
            .swui-frame > .swui-fill-h,
            .swui-scroll-view > .swui-fill-h,
            .swui-root > .swui-fill-h
            """) {
                .alignSelf("stretch")
            }
            // Horizontal fill under a row parent -> grow along the main axis.
            rule("""
            .swui-hstack > .swui-fill-h,
            .swui-lazy-hstack > .swui-fill-h,
            .swui-toolbar > .swui-fill-h
            """) {
                .flex("1 1 0%")
                .minWidth("0")
            }
            // Vertical fill under a row parent -> stretch the cross axis.
            rule("""
            .swui-hstack > .swui-fill-v,
            .swui-lazy-hstack > .swui-fill-v,
            .swui-toolbar > .swui-fill-v
            """) {
                .alignSelf("stretch")
            }
            // Vertical fill under a column parent -> grow along the main axis.
            rule("""
            .swui-vstack > .swui-fill-v,
            .swui-lazy-vstack > .swui-fill-v,
            .swui-card > .swui-fill-v,
            .swui-frame > .swui-fill-v,
            .swui-root > .swui-fill-v
            """) {
                .flex("1 1 0%")
                .minHeight("0")
            }
            // Upward propagation: a container holding a horizontal-fill
            // descendant is itself horizontally greedy in its column parent.
            rule("""
            .swui-vstack:has(.swui-fill-h),
            .swui-lazy-vstack:has(.swui-fill-h),
            .swui-hstack:has(.swui-fill-h),
            .swui-lazy-hstack:has(.swui-fill-h),
            .swui-card:has(.swui-fill-h),
            .swui-toolbar:has(.swui-fill-h)
            """) {
                .alignSelf("stretch")
            }
            // A row that contains a Spacer is horizontally greedy; carry that
            // intent up to one enclosing column level.
            rule("""
            .swui-hstack:has(> .swui-spacer),
            .swui-toolbar:has(> .swui-spacer),
            .swui-card:has(.swui-hstack > .swui-spacer),
            .swui-card:has(.swui-toolbar > .swui-spacer),
            .swui-vstack:has(.swui-hstack > .swui-spacer),
            .swui-vstack:has(.swui-toolbar > .swui-spacer)
            """) {
                .alignSelf("stretch")
            }
            // Row-parent override: a greedy column/card that is itself a row
            // item grows on the main axis instead of stretching the cross axis.
            rule("""
            .swui-hstack > .swui-vstack:has(.swui-fill-h),
            .swui-hstack > .swui-lazy-vstack:has(.swui-fill-h),
            .swui-hstack > .swui-card:has(.swui-fill-h),
            .swui-toolbar > .swui-vstack:has(.swui-fill-h),
            .swui-toolbar > .swui-card:has(.swui-fill-h)
            """) {
                .flex("1 1 0%")
                .minWidth("0")
                .alignSelf("auto")
            }
            // Explicit hug blocks fill and propagation. Declared after the
            // fill/:has rules so equal-specificity selectors win by source order.
            rule(".swui-hug-h") {
                .alignSelf("flex-start")
            }
            rule("""
            .swui-vstack.swui-hug-h,
            .swui-lazy-vstack.swui-hug-h,
            .swui-hstack.swui-hug-h,
            .swui-lazy-hstack.swui-hug-h,
            .swui-card.swui-hug-h,
            .swui-toolbar.swui-hug-h
            """) {
                .alignSelf("flex-start")
            }
            rule("""
            .swui-hstack > .swui-hug-h,
            .swui-lazy-hstack > .swui-hug-h,
            .swui-toolbar > .swui-hug-h
            """) {
                .flex("0 0 auto")
                .alignSelf("auto")
            }
            // Vertical hug, parent-axis aware.
            rule("""
            .swui-vstack > .swui-hug-v,
            .swui-lazy-vstack > .swui-hug-v,
            .swui-card > .swui-hug-v,
            .swui-root > .swui-hug-v
            """) {
                .flex("0 0 auto")
            }
            rule("""
            .swui-hstack > .swui-hug-v,
            .swui-lazy-hstack > .swui-hug-v,
            .swui-toolbar > .swui-hug-v
            """) {
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
                .boxSizing("border-box")
                .transition("background var(--swui-motion-quick), border-color var(--swui-motion-quick), opacity var(--swui-motion-quick)")
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
                // design-style default avoids depending on an ancestor-resolved token.
                .background("var(--swui-control-tint, var(--swui-button-primary-background))")
            }
            rule(".swui-button-secondary") {
                .color("var(--swui-button-secondary-foreground)")
                .background("var(--swui-button-secondary-background)")
                .borderColor("var(--swui-button-secondary-border)")
            }
            rule(".swui-button-plain") {
                .color("var(--swui-control-tint, var(--swui-button-plain-foreground))")
                .background("transparent")
                .borderColor("transparent")
                .paddingInline("0")
            }
            rule(".swui-button-secondary:hover") {
                .background("var(--swui-button-secondary-hover-background)")
            }
            rule("""
            .swui-control-disabled,
            .swui-button:disabled,
            .swui-text-field:disabled,
            .swui-picker:disabled,
            .swui-slider:disabled
            """) {
                .cursor("default")
                .opacity("var(--swui-control-disabled-opacity)")
            }
            rule(".swui-modifier") {
                .boxSizing("border-box")
            }
            rule("""
            .swui-style,
            .swui-attribute
            """) {
                .display("inline")
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
            rule(".swui-badge") {
                .display("inline-flex")
                .alignItems("center")
                .width("fit-content")
                .borderRadius("var(--swui-badge-radius)")
                .padding("var(--swui-badge-padding)")
                .background("var(--swui-badge-background)")
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
            rule(".swui-value-display") {
                .display("grid")
                .justifyItems("center")
                .gap("var(--swui-space-xs)")
                .padding("var(--swui-value-display-padding)")
                .borderRadius("var(--swui-value-display-radius)")
                .background("var(--swui-value-display-background)")
                .border("var(--swui-value-display-border)")
            }
            rule(".swui-value-label") {
                .color("var(--swui-text-muted)")
                .fontSize("13px")
            }
            rule(".swui-value") {
                .minWidth("72px")
                .textAlign("center")
                .fontSize("var(--swui-value-size)")
                .fontWeight("var(--swui-value-weight)")
                .lineHeight("1")
                .color("var(--swui-accent)")
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
            rule("""
            .swui-hstack > .swui-divider,
            .swui-lazy-hstack > .swui-divider,
            .swui-toolbar > .swui-divider
            """) {
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
            rule(".swui-field") {
                .display("grid")
                .gap("var(--swui-space-xs)")
                .color("var(--swui-text)")
            }
            rule(".swui-picker-field") {
                .display("grid")
                .gap("var(--swui-space-xs)")
            }
            rule("""
            .swui-field-label,
            .swui-toggle-label
            """) {
                .color("var(--swui-text-muted)")
                .fontSize("var(--swui-field-label-size)")
            }
            rule("""
            .swui-text-field,
            .swui-picker
            """) {
                .minHeight("var(--swui-control-regular-height)")
                .border("var(--swui-field-border)")
                .borderRadius("var(--swui-field-radius)")
                .padding("var(--swui-field-padding)")
                .boxSizing("border-box")
                .color("var(--swui-text)")
                .background("var(--swui-field-background)")
                .font("inherit")
            }
            rule(".swui-slider") {
                .accentColor("var(--swui-tint, var(--swui-accent))")
                .minWidth("160px")
            }
            rule(".swui-stepper") {
                .display("inline-flex")
                .alignItems("center")
                .gap("var(--swui-space-sm)")
            }
            rule(".swui-stepper-label") {
                .color("var(--swui-text-muted)")
                .fontSize("13px")
            }
            rule(".swui-stepper-value") {
                .minWidth("3ch")
                .textAlign("center")
                .fontWeight("600")
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
            rule(".swui-toggle-control") {
                .width("var(--swui-toggle-width)")
                .height("var(--swui-toggle-height)")
                .borderRadius("var(--swui-radius-pill)")
                .border("1px solid var(--swui-border)")
                .background("var(--swui-surface-raised)")
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
        }
    }
}
