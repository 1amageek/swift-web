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
            let _ = registry.registerScript(id: "swui-storyboard-scheme", body: StoryboardSchemeScript.script)
            EmptyHTML()
        } else {
            style {
                rawHTML(StoryboardStylesheet.css)
            }
            rawHTML("<script>\(StoryboardSchemeScript.script)</script>")
        }
        content
    }
}

/// The catalog's color-scheme switcher. The document root carries
/// `data-color-scheme` (the palette contract), so the chips just set or clear
/// that attribute and persist the choice in a cookie; "auto" clears it and lets
/// the user-agent preference drive the palette through the media query.
enum StoryboardSchemeScript {
    static let script = """
    (function(){
    if(window.__swuiStoryboardScheme)return;window.__swuiStoryboardScheme=true;
    var KEY='swui-storyboard-scheme';
    function clean(value){return value==='light'||value==='dark'||value==='auto'?value:'auto';}
    function root(){return document.body&&document.body.classList.contains('swui-root')?document.body:document.querySelector('.swui-root');}
    function apply(value){
    value=clean(value);
    var target=root();if(!target)return;
    if(value==='light'||value==='dark'){target.setAttribute('data-color-scheme',value);}
    else{target.removeAttribute('data-color-scheme');}
    document.querySelectorAll('[data-scheme-chip]').forEach(function(chip){
    chip.classList.toggle('swui-storyboard-chip-selected',chip.getAttribute('data-scheme-chip')===value);
    });
    }
    function readCookie(){
    try{
    var name=KEY+'=';
    var parts=document.cookie?document.cookie.split(';'):[];
    for(var i=0;i<parts.length;i++){
    var part=parts[i].trim();
    if(part.indexOf(name)===0)return decodeURIComponent(part.slice(name.length));
    }
    }catch(error){}
    return 'auto';
    }
    function writeCookie(value){
    try{document.cookie=KEY+'='+encodeURIComponent(clean(value))+'; Path=/storyboard; Max-Age=31536000; SameSite=Lax';}catch(error){}
    }
    function boot(){
    apply(readCookie());
    document.addEventListener('click',function(event){
    var chip=event.target&&event.target.closest?event.target.closest('[data-scheme-chip]'):null;
    if(!chip)return;
    var value=chip.getAttribute('data-scheme-chip');
    writeCookie(value);
    apply(value);
    });
    document.addEventListener('keydown',function(event){
    if((event.metaKey||event.ctrlKey)&&(event.key==='k'||event.key==='K')){
    var trigger=document.querySelector('[data-quick-open-trigger]');
    if(trigger){event.preventDefault();trigger.click();focusQuickOpen();}
    return;
    }
    if(event.key==='Escape'){
    var close=document.querySelector('[data-quick-open-close]');
    if(close){close.click();}
    }
    });
    document.addEventListener('click',function(event){
    var trigger=event.target&&event.target.closest?event.target.closest('[data-quick-open-trigger]'):null;
    if(trigger){focusQuickOpen();}
    });
    }
    function focusQuickOpen(){
    var attempts=0;
    function tryFocus(){
    var input=document.querySelector('[data-quick-open-input] input, input[data-quick-open-input]');
    if(input){input.focus();return;}
    if(attempts++<20){requestAnimationFrame(tryFocus);}
    }
    requestAnimationFrame(tryFocus);
    }
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
    })();
    """
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
            // ── Atmosphere ────────────────────────────────────────────────
            // The catalog is itself the Liquid Glass demo: every shell surface
            // is real glass, so the page needs depth behind it. A fixed, layered
            // gradient field gives all glass something to refract; the dark
            // variant swaps to deep slate with the same geometry.
            // The document body is the framework's app frame (`swui-viewport`:
            // 100vh flex, overflow hidden), so the catalog scrolls inside its
            // columns, not as a document. Attribute-modifier wrappers are
            // `display: contents`, so the flex sizing chain passes through
            // them: app → VStack → shell row → columns.
            rule(cls("swui-storyboard-app")) {
                .position("relative")
                  .boxSizing("border-box")
                  .isolation("isolate")
                  .display("flex")
                  .flexDirection("column")
                  .flex("1 1 auto")
                  .minHeight("0")
                  .minWidth("0")
            }
            // The frame column (top bar + shell row) fills the app and caps
            // its height so the shell can hand bounded heights to the columns.
            rule(cls("swui-storyboard-frame")) {
                .flex("1 1 auto")
                  .minHeight("0")
                  .width("100%")
                  .boxSizing("border-box")
            }
            // Column widths and the detail flex live here instead of .frame
            // modifiers so the constraints sit on the real flex items.
            rule(cls("swui-storyboard-rail-sidebar")) {
                .flex("0 0 226px")
                  .width("226px")
            }
            rule(cls("swui-storyboard-rail-inspector")) {
                .flex("0 0 184px")
                  .width("184px")
            }
            rule(cls("swui-storyboard-detail")) {
                .flex("1 1 auto")
                  .minWidth("0")
                  .minHeight("0")
            }
            rule(cls("swui-storyboard-app").pseudoElement(.before)) {
                .content("\"\"")
                  .position("fixed")
                  .inset("0")
                  .zIndex("-1")
                  .background(
                    "radial-gradient(1200px 800px at 12% -8%, color-mix(in srgb, var(--swui-accent) 16%, transparent), transparent 60%), "
                    + "radial-gradient(1000px 700px at 88% 4%, color-mix(in srgb, #b66dff 14%, transparent), transparent 55%), "
                    + "radial-gradient(900px 900px at 78% 96%, color-mix(in srgb, #2ec8a6 11%, transparent), transparent 60%), "
                    + "radial-gradient(700px 500px at 8% 88%, color-mix(in srgb, var(--swui-accent) 9%, transparent), transparent 55%), "
                    + "var(--swui-background)"
                  )
            }
            rule(cls("swui-storyboard-app").pseudoElement(.after)) {
                .content("\"\"")
                  .position("fixed")
                  .inset("0")
                  .zIndex("-1")
                  .backgroundImage("radial-gradient(color-mix(in srgb, var(--swui-text) 7%, transparent) 1px, transparent 1px)")
                  .backgroundSize("22px 22px")
                  .maskImage("linear-gradient(180deg, rgba(0,0,0,0.5), rgba(0,0,0,0.15) 40%, rgba(0,0,0,0.4))")
            }
            // ── Shell rails ───────────────────────────────────────────────
            // Sidebar and inspector float as inset glass panels over the
            // atmosphere instead of butting into the viewport edges.
            // Each rail owns its own scroll region inside the app frame. The
            // border-radius on the scrolling element clips its content, so no
            // overflow: hidden is needed (that would freeze scrolling).
            rule(cls("swui-storyboard-rail")) {
                .boxSizing("border-box")
                  .borderRadius("var(--swui-radius-large)")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 55%, transparent)")
                  .overflowY("auto")
                  .minHeight("0")
            }
            // The shell row absorbs the viewport height left under the top bar
            // and stretches its three columns, giving every column's scroll
            // container a bounded height.
            rule(cls("swui-storyboard-shell")) {
                .boxSizing("border-box")
                  .width("100%")
                  .padding("0 14px 14px")
                  .flex("1 1 auto")
                  .minHeight("0")
                  .alignItems("stretch")
            }
            rule(cls("swui-storyboard-shell").child(StyleSelector.universal)) {
                .minHeight("0")
            }
            // The app frame never scrolls as a document, so the bar is simply
            // the first fixed row of the frame.
            rule(cls("swui-storyboard-topbar")) {
                .zIndex("30")
                  .margin("10px 14px 0")
                  .flex("0 0 auto")
            }
            // ── Detail sections ───────────────────────────────────────────
            rule(cls("swui-storyboard-eyebrow")) {
                .letterSpacing("0.08em")
                  .textTransform("uppercase")
                  .fontSize("11px")
                  .fontWeight("650")
                  .color("var(--swui-accent)")
            }
            rule(cls("swui-storyboard-lede")) {
                .fontSize("15px")
                  .lineHeight("1.65")
                  .maxWidth("62ch")
            }
            rule(cls("swui-storyboard-section-rule")) {
                .width("100%")
                  .height("1px")
                  .background("color-mix(in srgb, var(--swui-border) 70%, transparent)")
                  .margin("6px 0 2px")
            }
            rule(cls("swui-storyboard-code-chip")) {
                .fontFamily("ui-monospace, SFMono-Regular, Menlo, monospace")
                  .fontSize("12px")
                  .padding("3px 8px")
                  .borderRadius("6px")
                  .backgroundColor("color-mix(in srgb, var(--swui-accent) 9%, var(--swui-surface))")
                  .color("color-mix(in srgb, var(--swui-accent) 80%, var(--swui-text))")
                  .whiteSpace("nowrap")
            }
            // ── Scenes ────────────────────────────────────────────────────
            // Glass is invisible against a void: every preview stage sits on a
            // curated gradient scene so materials, glass, and shadows always
            // have depth to work against. A faint lattice keeps it a canvas.
            rule(cls("swui-storyboard-scene")) {
                .position("relative")
                  .boxSizing("border-box")
                  .overflow("hidden")
                  .isolation("isolate")
            }
            rule(cls("swui-storyboard-scene").pseudoElement(.after)) {
                .content("\"\"")
                  .position("absolute")
                  .inset("0")
                  .zIndex("-1")
                  .backgroundImage("radial-gradient(color-mix(in srgb, var(--swui-text) 9%, transparent) 1px, transparent 1px)")
                  .backgroundSize("18px 18px")
            }
            rule(cls("swui-storyboard-scene-aurora")) {
                .background(
                    "radial-gradient(120% 140% at 8% 0%, color-mix(in srgb, var(--swui-accent) 26%, transparent), transparent 55%), "
                    + "radial-gradient(110% 130% at 92% 12%, color-mix(in srgb, #b66dff 24%, transparent), transparent 52%), "
                    + "radial-gradient(120% 120% at 55% 105%, color-mix(in srgb, #2ec8a6 18%, transparent), transparent 58%), "
                    + "var(--swui-surface)"
                  )
            }
            rule(cls("swui-storyboard-scene-dawn")) {
                .background(
                    "radial-gradient(130% 130% at 12% 8%, color-mix(in srgb, #ff9d66 22%, transparent), transparent 55%), "
                    + "radial-gradient(120% 140% at 88% 0%, color-mix(in srgb, #ff5f8f 18%, transparent), transparent 52%), "
                    + "radial-gradient(140% 120% at 50% 110%, color-mix(in srgb, var(--swui-accent) 16%, transparent), transparent 60%), "
                    + "var(--swui-surface)"
                  )
            }
            rule(cls("swui-storyboard-scene-mist")) {
                .background(
                    "radial-gradient(140% 120% at 20% 0%, color-mix(in srgb, var(--swui-accent) 13%, transparent), transparent 60%), "
                    + "radial-gradient(120% 140% at 90% 100%, color-mix(in srgb, #7ba7cc 16%, transparent), transparent 55%), "
                    + "var(--swui-surface)"
                  )
            }
            rule(cls("swui-storyboard-scene-meadow")) {
                .background(
                    "radial-gradient(130% 130% at 10% 100%, color-mix(in srgb, #2ec8a6 20%, transparent), transparent 58%), "
                    + "radial-gradient(120% 130% at 85% 0%, color-mix(in srgb, #8ad34f 14%, transparent), transparent 55%), "
                    + "var(--swui-surface)"
                  )
            }
            // ── Variants gallery ──────────────────────────────────────────
            rule(cls("swui-storyboard-variants")) {
                .display("grid")
                  .gridTemplateColumns("repeat(auto-fill, minmax(220px, 1fr))")
                  .width("100%")
                  .boxSizing("border-box")
                Style.gap("14px")
            }
            rule(cls("swui-storyboard-variant")) {
                .display("flex")
                  .flexDirection("column")
                  .borderRadius("14px")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 60%, transparent)")
                  .overflow("hidden")
                  .backgroundColor("color-mix(in srgb, var(--swui-surface) 72%, transparent)")
                Style.backdropFilter("blur(10px)")
            }
            rule(cls("swui-storyboard-variant-stage")) {
                .display("flex")
                  .alignItems("center")
                  .justifyContent("center")
                  .minHeight("124px")
                  .padding("20px")
                  .boxSizing("border-box")
            }
            rule(cls("swui-storyboard-variant-caption")) {
                .display("flex")
                  .flexDirection("column")
                  .padding("10px 12px 12px")
                  .borderTop("1px solid color-mix(in srgb, var(--swui-border) 55%, transparent)")
                Style.gap("3px")
            }
            // ── Properties table ──────────────────────────────────────────
            rule(cls("swui-storyboard-props")) {
                .display("grid")
                  .gridTemplateColumns("minmax(140px, max-content) 1fr")
                  .width("100%")
                  .boxSizing("border-box")
                  .borderRadius("12px")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 60%, transparent)")
                  .overflow("hidden")
                  .backgroundColor("color-mix(in srgb, var(--swui-surface) 72%, transparent)")
                Style.backdropFilter("blur(10px)")
            }
            // ── Quick open ────────────────────────────────────────────────
            rule(cls("swui-storyboard-quickopen")) {
                .position("relative")
                  .flex("1 1 auto")
                  .minWidth("0")
            }
            rule(cls("swui-storyboard-search-trigger")) {
                .width("100%")
                  .boxSizing("border-box")
                  .padding("7px 12px")
                  .borderRadius("9px")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 60%, transparent)")
                  .backgroundColor("color-mix(in srgb, var(--swui-surface) 62%, transparent)")
                  .textAlign("left")
                  .cursor("pointer")
            }
            rule(cls("swui-storyboard-quickopen-overlay")) {
                .position("fixed")
                  .inset("0")
                  .zIndex("60")
                  .display("flex")
                  .alignItems("flex-start")
                  .justifyContent("center")
                  .paddingTop("14vh")
            }
            rule(cls("swui-storyboard-quickopen-backdrop")) {
                .position("absolute")
                  .inset("0")
                  .border("none")
                  .background("color-mix(in srgb, var(--swui-text) 22%, transparent)")
                  .cursor("default")
                Style.backdropFilter("blur(4px)")
            }
            // Keep the backdrop's accessible name for screen readers while
            // visually hiding the label text.
            rule(cls("swui-storyboard-quickopen-backdrop").descendant(cls("swui-text"))) {
                .position("absolute")
                  .width("1px")
                  .height("1px")
                  .overflow("hidden")
                  .whiteSpace("nowrap")
                Style.clipPath("inset(50%)")
            }
            rule(cls("swui-storyboard-quickopen-panel")) {
                .position("relative")
                  .width("min(600px, 92vw)")
                  .maxHeight("62vh")
                  .display("flex")
                  .flexDirection("column")
                  .borderRadius("16px")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 55%, transparent)")
                  .overflow("hidden")
                  .boxShadow("0 24px 70px color-mix(in srgb, var(--swui-text) 22%, transparent)")
            }
            rule(cls("swui-storyboard-quickopen-field").descendant(cls("swui-field-label"))) {
                .display("none")
            }
            rule(cls("swui-storyboard-quickopen-field").descendant(.element(.input))) {
                .width("100%")
                  .boxSizing("border-box")
                  .fontSize("15px")
                  .padding("14px 16px")
                  .border("none")
                  .borderBottom("1px solid color-mix(in srgb, var(--swui-border) 55%, transparent)")
                  .background("transparent")
                  .color("var(--swui-text)")
                  .outline("none")
            }
            rule(cls("swui-storyboard-quickopen-list")) {
                .overflow("auto")
                  .padding("6px")
                  .display("flex")
                  .flexDirection("column")
                Style.gap("2px")
            }
            rule(cls("swui-storyboard-quickopen-row")) {
                .display("block")
                  .padding("9px 12px")
                  .borderRadius("10px")
                  .textDecoration("none")
            }
            rule(cls("swui-storyboard-quickopen-row").pseudo(.hover)) {
                .backgroundColor("color-mix(in srgb, var(--swui-accent) 10%, transparent)")
            }
            // ── Scheme chips ──────────────────────────────────────────────
            rule(cls("swui-storyboard-chip")) {
                  .border("none")
                  .background("transparent")
                  .fontSize("13px")
                  .fontWeight("500")
                  .color("var(--swui-text)")
                  .padding("0 11px")
                  .height("30px")
                  .borderRadius("6px")
                  .cursor("pointer")
              Style.appearance("none")
            }
            rule(cls("swui-storyboard-chip-selected")) {
                .backgroundColor("var(--swui-surface-raised)")
                  .boxShadow("0 1px 3px color-mix(in srgb, var(--swui-text) 12%, transparent)")
            }
            rule(cls("swui-storyboard-props-row")) {
                .display("grid")
                  .gridColumn("1 / -1")
                  .gridTemplateColumns("subgrid")
                  .padding("10px 14px")
                  .alignItems("baseline")
                Style.gap("14px")
            }
            rule(cls("swui-storyboard-props-row").not(StyleSelector.pseudo(.firstChild))) {
                .borderTop("1px solid color-mix(in srgb, var(--swui-border) 45%, transparent)")
            }
            rule(cls("swui-storyboard-preview-frame")) {
                .width("100%")
                  .boxSizing("border-box")
                  .border("1px solid color-mix(in srgb, var(--swui-border) 60%, transparent)")
                  .borderRadius("16px")
                  .overflow("hidden")
                  .backgroundColor("color-mix(in srgb, var(--swui-surface) 72%, transparent)")
                Style.backdropFilter("blur(10px)")
            }
            rule(cls("swui-storyboard-preview-canvas")) {
                .width("100%")
                  .boxSizing("border-box")
                  .minHeight("260px")
                  .alignItems("center")
                  .justifyContent("center")
                  .padding("36px")
            }
            rule(
                cls("swui-storyboard-preview-canvas")
                  .child(cls("swui-animation-scope"))
                  .child(cls("swui-storyboard-section-demo"))
            ) {
                .alignSelf("stretch")
                  .width("100%")
                  .boxSizing("border-box")
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
            rule(cls("swui-storyboard-swatch-red")) {
                .backgroundColor("#ff3b30")
            }
            rule(cls("swui-storyboard-swatch-yellow")) {
                .backgroundColor("#ffcc00")
            }
            rule(cls("swui-storyboard-swatch-indigo")) {
                .backgroundColor("#5856d6")
            }
            rule(cls("swui-storyboard-runtime-summary")) {
                .boxSizing("border-box")
                  .width("100%")
                  .margin("0")
                  .padding("8px 9px")
                  .border("1px solid var(--swui-border)")
                  .borderRadius("7px")
                  .backgroundColor("var(--swui-surface-raised)")
                  .color("var(--swui-text)")
                  .fontFamily("ui-monospace, SFMono-Regular, Menlo, monospace")
                  .fontSize("11px")
                  .lineHeight("1.35")
                  .whiteSpace("pre-wrap")
            }
            rule(cls("swui-storyboard-runtime-log")) {
                .boxSizing("border-box")
                  .width("100%")
                  .maxHeight("260px")
                  .margin("0")
                  .padding("8px 9px")
                  .border("1px solid var(--swui-border)")
                  .borderRadius("7px")
                  .backgroundColor("var(--swui-surface)")
                  .color("var(--swui-text-muted)")
                  .fontFamily("ui-monospace, SFMono-Regular, Menlo, monospace")
                  .fontSize("11px")
                  .lineHeight("1.35")
                  .overflow("auto")
                  .whiteSpace("pre-wrap")
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
