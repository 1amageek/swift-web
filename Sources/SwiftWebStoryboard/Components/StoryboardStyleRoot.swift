import SwiftHTML
import SwiftWebStyle

struct StoryboardStyleRoot<Content: HTML>: Component {
    private let content: Content

    init(@HTMLBuilder content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    var body: some HTML {
        if let registry = StyleRegistry.current {
            let _ = registry.registerStylesheet(StoryboardStylesheet.css)
            EmptyHTML()
        } else {
            style {
                rawHTML(StoryboardStylesheet.css)
            }
        }
        content
    }
}

private enum StoryboardStylesheet {
    private static func cls(_ name: String) -> StyleSelector {
        .class(StyleClass(name))
    }

    static var css: String {
        stylesheet.cssText
    }

    static var stylesheet: Stylesheet {
        Stylesheet {
            rule(cls("swui-storyboard-preview-frame")) {
                .width("100%")
                  .boxSizing("border-box")
                  .border("1px solid var(--swui-border)")
                  .borderRadius("12px")
                  .overflow("hidden")
            }
            rule(cls("swui-storyboard-preview-canvas")) {
                .width("100%")
                  .boxSizing("border-box")
                  .minHeight("220px")
                  .alignItems("center")
                  .justifyContent("center")
                  .padding("32px")
                  .backgroundColor("var(--swui-surface)")
                  .backgroundImage("radial-gradient(var(--swui-border) 1.1px, transparent 1.1px)")
                  .backgroundSize("18px 18px")
            }
            rule(cls("swui-storyboard-control-panel")) {
                .borderTop("1px solid var(--swui-border)")
                  .display("flex")
                  .flexWrap("wrap")
                  .alignItems("center")
                  .gap("10px 18px")
                  .padding("12px 14px")
            }
            rule(cls("swui-storyboard-color-input")) {
                .width("44px")
                  .height("28px")
                  .padding("2px")
                  .border("1px solid var(--swui-border)")
                  .borderRadius("8px")
                  .backgroundColor("var(--swui-surface)")
                  .cursor("pointer")
                  .boxSizing("border-box")
            }
            rule(cls("swui-storyboard-text-input")) {
                .width("168px")
                  .padding("6px 10px")
                  .border("1px solid var(--swui-border)")
                  .borderRadius("8px")
                  .fontSize("13px")
                  .backgroundColor("var(--swui-surface)")
                  .color("var(--swui-text)")
                  .outline("none")
                  .boxSizing("border-box")
            }
            rule(cls("swui-storyboard-range-widget")) {
                .display("grid")
                  .gridTemplateColumns("132px 4ch")
                  .alignItems("center")
                  .gap("8px")
            }
            rule(cls("swui-storyboard-range-widget").descendant(cls("swui-storyboard-range-slider"))) {
                .width("132px")
                  .minWidth("0")
            }
            rule(cls("swui-storyboard-range-readout")) {
                .display("inline-block")
                  .width("4ch")
                  .minWidth("4ch")
                  .textAlign("right")
                  .fontVariantNumeric("tabular-nums")
            }
            rule(cls("swui-storyboard-swatch-button")) {
                .width("28px")
                  .height("28px")
                  .display("inline-flex")
                  .alignItems("center")
                  .justifyContent("center")
            }
            rule(cls("swui-storyboard-swatch")) {
                .width("18px")
                  .height("18px")
                  .borderRadius("999px")
            }
            rule(cls("swui-storyboard-swatch-selected")) {
                .boxShadow("0 0 0 2px var(--swui-surface), 0 0 0 4px var(--swui-accent)")
            }
            rule(cls("swui-storyboard-swatch-unselected")) {
                .boxShadow("inset 0 0 0 1px var(--swui-border)")
            }
            rule(cls("swui-storyboard-swatch-accent")) {
                .backgroundColor("var(--swui-accent)")
            }
            rule(cls("swui-storyboard-swatch-danger")) {
                .backgroundColor("var(--swui-danger)")
            }
            rule(cls("swui-storyboard-swatch-primary")) {
                .backgroundColor("var(--swui-text)")
            }
            rule(cls("swui-storyboard-swatch-secondary")) {
                .backgroundColor("var(--swui-text-muted)")
            }
            rule(cls("swui-storyboard-swatch-blue")) {
                .backgroundColor("#007aff")
            }
            rule(cls("swui-storyboard-swatch-green")) {
                .backgroundColor("#34c759")
            }
            rule(cls("swui-storyboard-swatch-orange")) {
                .backgroundColor("#ff9500")
            }
            rule(cls("swui-storyboard-swatch-pink")) {
                .backgroundColor("#ff2d55")
            }
            rule(cls("swui-storyboard-swatch-purple")) {
                .backgroundColor("#af52de")
            }
            rule(cls("swui-storyboard-alignment-frame")) {
                .width("420px")
                  .maxWidth("80vw")
                  .height("120px")
                  .boxSizing("border-box")
                  .border("1.5px dashed var(--swui-border)")
                  .borderRadius("10px")
                  .display("flex")
                  .alignItems("center")
                  .padding("0 14px")
            }
            rule(cls("swui-storyboard-jc-leading")) {
                .justifyContent("flex-start")
            }
            rule(cls("swui-storyboard-jc-center")) {
                .justifyContent("center")
            }
            rule(cls("swui-storyboard-jc-trailing")) {
                .justifyContent("flex-end")
            }
            rule(cls("swui-storyboard-material-stage")) {
                .position("relative")
                  .width("100%")
                  .boxSizing("border-box")
                  .minHeight("300px")
                  .borderRadius("20px")
                  .overflow("hidden")
                  .display("flex")
                  .alignItems("center")
                  .padding("28px")
                  .backgroundImage("linear-gradient(135deg, #4338ca 0%, #7c3aed 48%, #db2777 100%)")
            }
            rule(cls("swui-storyboard-material-word")) {
                .position("absolute")
                  .top("0")
                  .right("0")
                  .bottom("0")
                  .left("0")
                  .display("flex")
                  .alignItems("center")
                  .justifyContent("center")
                  .zIndex("0")
                  .color("rgba(255,255,255,0.22)")
                  .fontSize("96px")
                  .fontWeight("800")
                  .letterSpacing("-3px")
                  .pointerEvents("none")
                  .whiteSpace("nowrap")
            }
            rule(cls("swui-storyboard-material-content")) {
                .position("relative")
                  .zIndex("1")
                  .width("100%")
            }
            rule(cls("swui-storyboard-device")) {
                .position("relative")
                  .width("188px")
                  .height("300px")
                  .border("6px solid var(--swui-text)")
                  .borderRadius("30px")
                  .overflow("hidden")
                  .background("var(--swui-surface-raised)")
            }
            rule(cls("swui-storyboard-device-notch").descendant(cls("swui-storyboard-safe-area"))) {
                .top("30px")
                  .bottom("18px")
            }
            rule(cls("swui-storyboard-device-browser").descendant(cls("swui-storyboard-safe-area"))) {
                .top("26px")
                  .bottom("0")
            }
            rule(cls("swui-storyboard-device-none").descendant(cls("swui-storyboard-safe-area"))) {
                .top("8px")
                  .bottom("8px")
            }
            rule(cls("swui-storyboard-safe-area")) {
                .position("absolute")
                  .left("8px")
                  .right("8px")
                  .border("1.5px dashed color-mix(in srgb, var(--swui-accent) 55%, transparent)")
                  .borderRadius("8px")
                  .background("color-mix(in srgb, var(--swui-accent) 9%, transparent)")
                  .display("flex")
                  .alignItems("center")
                  .justifyContent("center")
            }
            rule(cls("swui-storyboard-chrome-band")) {
                .position("absolute")
                  .left("0")
                  .right("0")
                  .background("repeating-linear-gradient(45deg, color-mix(in srgb, var(--swui-text-muted) 22%, transparent), color-mix(in srgb, var(--swui-text-muted) 22%, transparent) 4px, transparent 4px, transparent 8px)")
            }
            rule(cls("swui-storyboard-chrome-top")) {
                .top("0")
            }
            rule(cls("swui-storyboard-chrome-bottom")) {
                .bottom("0")
            }
            rule(cls("swui-storyboard-device-notch").descendant(cls("swui-storyboard-chrome-top"))) {
                .height("30px")
            }
            rule(cls("swui-storyboard-device-notch").descendant(cls("swui-storyboard-chrome-bottom"))) {
                .height("18px")
            }
            rule(cls("swui-storyboard-device-browser").descendant(cls("swui-storyboard-chrome-top"))) {
                .height("26px")
            }
            rule(cls("swui-storyboard-notch")) {
                .width("96px")
                  .height("18px")
                  .background("#000")
                  .borderRadius("0 0 12px 12px")
                  .margin("0 auto")
            }
            rule(cls("swui-storyboard-home-indicator")) {
                .width("90px")
                  .height("4px")
                  .borderRadius("2px")
                  .background("var(--swui-text-muted)")
                  .margin("7px auto 0")
                  .opacity("0.6")
            }
            rule(cls("swui-storyboard-grid-tile")) {
                .aspectRatio("1")
                  .borderRadius("10px")
                  .display("flex")
                  .alignItems("center")
                  .justifyContent("center")
                  .color("rgba(255,255,255,0.92)")
            }
            rule(cls("swui-storyboard-grid-tile-0")) { .background("#8fa9c4") }
            rule(cls("swui-storyboard-grid-tile-1")) { .background("#c4a98f") }
            rule(cls("swui-storyboard-grid-tile-2")) { .background("#8fc4a9") }
            rule(cls("swui-storyboard-grid-tile-3")) { .background("#a98fc4") }
            rule(cls("swui-storyboard-grid-tile-4")) { .background("#c48fa0") }
            rule(cls("swui-storyboard-grid-tile-5")) { .background("#9fb98f") }
            rule(cls("swui-storyboard-grid-tile-6")) { .background("#8fb6c4") }
            rule(cls("swui-storyboard-grid-tile-7")) { .background("#c4b08f") }
        }
    }
}
