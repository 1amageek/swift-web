import Foundation

/// Whether a catalog selection shows the "Rendered HTML" section. Pure
/// layout/foundation demos emit no meaningful DOM panel. This is the single
/// source of truth shared by the detail page (which renders the section and its
/// `#rendered-html` id) and the inspector table of contents (which lists the
/// matching anchor), so the two cannot drift into a dangling anchor.
func catalogShowsRenderedHTML(for id: String) -> Bool {
    !["gridsystem", "spacing", "alignment", "responsive", "safearea"].contains(id)
}

func catalogRenderedHTML(for id: String) -> String {
    switch id {
    case "typography":
        return #"<p class="swui-text">Hello, SwiftWebUI</p>"#
    case "code":
        return #"""
<pre class="swui-code-block" role="region">
  <code class="swui-code-block-content" data-language="swift">
    <span class="swui-code-line" data-line="1">...</span>
  </code>
</pre>
"""#
    case "button":
        return #"<button class="swui-button swui-button-primary swui-control-regular">Primary</button>"#
    case "button-styles":
        return #"<button class="swui-button swui-button-glass swui-control-regular">Glass</button>"#
    case "control-sizes":
        return #"<button class="swui-button swui-button-primary swui-control-large">Large</button>"#
    case "button-states":
        return #"<button class="swui-button swui-button-primary swui-control-disabled" disabled>Disabled</button>"#
    case "links":
        return #"<a class="swui-link" href="/docs">Documentation</a>"#
    case "menu":
        return #"<div class="swui-menu"><button class="swui-button swui-button-secondary">Options</button></div>"#
    case "toolbar":
        return #"<div class="swui-toolbar"><button class="swui-button">Back</button><span class="swui-spacer"></span></div>"#
    case "textfield":
        return #"""
<label class="swui-field">
  <span class="swui-field-label">Email</span>
  <input class="swui-text-field" type="email">
</label>
"""#
    case "securefield":
        return #"<input class="swui-text-field" type="password">"#
    case "texteditor":
        return #"<textarea class="swui-text-editor"></textarea>"#
    case "form":
        return #"<form class="swui-form" method="post"><button class="swui-button" type="submit">Subscribe</button></form>"#
    case "toggle":
        return #"<label class="swui-toggle"><input class="swui-toggle-input" type="checkbox"><span class="swui-toggle-control"></span></label>"#
    case "slider":
        return #"<input class="swui-slider" type="range" min="0" max="1">"#
    case "stepper":
        return #"<div class="swui-stepper"><button>−</button><span class="swui-stepper-value val">3</span><button>+</button></div>"#
    case "picker":
        return #"<div class="swui-picker-segmented"><button class="swui-picker-segment sel">List</button></div>"#
    case "datepicker":
        return #"<input class="swui-date-picker" type="date">"#
    case "colorpicker":
        return ##"<input type="color" value="#1769e0">"##
    case "color":
        return #"<button class="swui-button swui-button-primary" style="--swui-control-tint: var(--swui-accent);">Accent</button>"#
    case "image":
        return #"<span class="swui-image" data-system-name="star.fill"></span>"#
    case "colorvalue":
        return #"<div class="swui-color" style="background-color:#007aff;"></div>"#
    case "label":
        return #"<span class="swui-label"><span class="swui-label-icon"><span class="swui-image" data-system-name="checkmark.seal.fill"></span></span><span class="swui-label-title">Verified</span></span>"#
    case "groupbox":
        return #"<div class="swui-group-box"><div class="swui-group-box-title">Storage</div></div>"#
    case "list":
        return #"<div class="swui-list" role="list"><div class="swui-list-row" role="listitem">Wi-Fi</div></div>"#
    case "section":
        return #"<section class="swui-section"><div class="swui-section-header">Account</div></section>"#
    case "disclosuregroup":
        return #"<details class="swui-disclosure-group" open><summary class="swui-disclosure-summary">Advanced options</summary></details>"#
    case "grid":
        return #"<div class="swui-grid"><div class="swui-grid-cell"></div></div>"#
    case "lazy":
        return #"<div class="swui-scroll-view"><div class="swui-vstack">...</div></div>"#
    case "tabview":
        return #"<div class="swui-tabbar"><button class="swui-tab sel">Summary</button></div>"#
    case "stacks":
        return #"<div class="swui-hstack"><span class="swui-image"></span><div class="swui-vstack"></div></div>"#
    case "spacer":
        return #"<span class="swui-spacer"></span>"#
    case "divider":
        return #"<hr class="swui-divider">"#
    case "navigationstack":
        return #"<nav class="swui-navigation-stack" data-navigation-stack="true"></nav>"#
    case "navigationlink":
        return ##"<a class="swui-navigation-link" data-navigation-link="true" href="#settings">Settings</a>"##
    case "searchable":
        return #"<div class="swui-searchable"><input class="swui-search-field" type="search"></div>"#
    case "alert":
        return #"<div class="swui-presentation swui-presentation-alert" role="dialog"></div>"#
    case "sheet":
        return #"<div class="swui-presentation swui-presentation-sheet" role="dialog"></div>"#
    case "scrollview":
        return #"<div class="swui-scroll-view"><div class="swui-vstack">...</div></div>"#
    case "progressview":
        return #"<progress class="swui-progress-bar" value="0.35" max="1"></progress>"#
    case "gauge":
        return #"<div class="swui-gauge"><span class="swui-gauge-val">62</span></div>"#
    case "badge":
        return #"<span class="swui-badge">Ready</span>"#
    default:
        return #"<div class="swui-root"></div>"#
    }
}
