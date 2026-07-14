import SwiftHTML
import SwiftWebStyle

/// Where a popover panel sits relative to its anchor.
public enum PopoverPlacement: String, Sendable {
    case top
    case bottom
    case leading
    case trailing
}

/// Cross-axis alignment of a popover panel against its anchor.
public enum PopoverAlignment: String, Sendable {
    case start
    case center
    case end
}

/// Server-rendered popovers, working without any client runtime:
///
/// - ``HTML/popover(id:placement:content:)`` — a *press* popover on the HTML
///   Popover API (`popover` + `popovertarget`): top-layer display, outside
///   tap and Escape dismiss it, and the trigger needs no JavaScript. The
///   wrapped trigger must render a `<button>` (e.g. SwiftWebUI `Button`);
///   anchors cannot carry `popovertarget` per the HTML spec.
/// - ``HTML/hoverPopover(placement:content:)`` — a pure-CSS card shown while
///   the wrapped element is hovered or has focus within. Pointer devices get
///   the fast preview; touch devices use the press popover instead, so pair
///   both when the content matters.
///
/// Panels are pre-rendered into the page (SSR), so the two variants can share
/// one card component. Positioning of the press popover uses CSS anchor
/// positioning where the browser supports it and falls back to the Popover
/// API's centered default elsewhere.
enum PopoverStyle {
    static let css = """
    .swui-hover-anchor {
      position: relative;
      anchor-name: --swui-hover-anchor;
      anchor-scope: --swui-hover-anchor;
    }
    .swui-hover-popover {
      position: absolute;
      z-index: 40;
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
      transition: opacity .12s ease .06s, visibility 0s linear .18s;
    }
    .swui-hover-anchor:hover > .swui-hover-popover,
    .swui-hover-anchor:focus-within > .swui-hover-popover {
      opacity: 1;
      visibility: visible;
      pointer-events: auto;
      transition-delay: .12s, 0s;
    }
    .swui-hover-popover[data-placement="top"] { bottom: calc(100% + 8px); }
    .swui-hover-popover[data-placement="bottom"] { top: calc(100% + 8px); }
    @supports (anchor-name: --swui-anchor) and (anchor-scope: --swui-anchor) {
      .swui-hover-popover[data-placement] {
        position: fixed;
        position-anchor: --swui-hover-anchor;
        inset: auto;
        transform: none;
        margin: 8px 0;
      }
      .swui-hover-popover[data-placement="top"][data-alignment="center"] { position-area: top; }
      .swui-hover-popover[data-placement="top"][data-alignment="start"] { position-area: top span-right; }
      .swui-hover-popover[data-placement="top"][data-alignment="end"] { position-area: top span-left; }
      .swui-hover-popover[data-placement="bottom"][data-alignment="center"] { position-area: bottom; }
      .swui-hover-popover[data-placement="bottom"][data-alignment="start"] { position-area: bottom span-right; }
      .swui-hover-popover[data-placement="bottom"][data-alignment="end"] { position-area: bottom span-left; }
      .swui-hover-popover[data-placement="leading"] { position-area: left; margin: 0 8px; }
      .swui-hover-popover[data-placement="trailing"] { position-area: right; margin: 0 8px; }
    }
    .swui-hover-popover[data-placement="top"][data-alignment="center"],
    .swui-hover-popover[data-placement="bottom"][data-alignment="center"] {
      left: 50%;
      transform: translateX(-50%);
    }
    .swui-hover-popover[data-placement="top"][data-alignment="start"],
    .swui-hover-popover[data-placement="bottom"][data-alignment="start"] { left: 0; }
    .swui-hover-popover[data-placement="top"][data-alignment="end"],
    .swui-hover-popover[data-placement="bottom"][data-alignment="end"] { right: 0; }
    .swui-hover-popover[data-placement="leading"] {
      right: calc(100% + 8px);
      top: 50%;
      transform: translateY(-50%);
    }
    .swui-hover-popover[data-placement="trailing"] {
      left: calc(100% + 8px);
      top: 50%;
      transform: translateY(-50%);
    }
    .swui-popover {
      margin: 0;
      padding: 0;
      border: 0;
      background: transparent;
      overflow: visible;
    }
    @supports (anchor-name: --swui-anchor) {
      .swui-popover[data-placement="top"] { position-area: top; margin-bottom: 8px; }
      .swui-popover[data-placement="bottom"] { position-area: bottom; margin-top: 8px; }
      .swui-popover[data-placement="leading"] { position-area: left; margin-right: 8px; }
      .swui-popover[data-placement="trailing"] { position-area: right; margin-left: 8px; }
    }
    """
}

/// A press-triggered popover panel on the HTML Popover API. Give the
/// triggering `<button>` a `.popoverTarget(id)` attribute and place the
/// panel anywhere on the page (it opens in the browser's top layer and
/// light-dismisses on outside tap / Escape). The invoking button is the
/// panel's implicit CSS anchor, so `data-placement` positioning works
/// without extra plumbing on browsers with anchor positioning.
public struct Popover<Panel: HTML>: Component {
    private let id: String
    private let placement: PopoverPlacement
    private let panel: Panel

    public init(
        id: String,
        placement: PopoverPlacement = .top,
        @HTMLBuilder content: () -> Panel
    ) {
        self.id = id
        self.placement = placement
        self.panel = content()
    }

    public var body: some HTML {
        let _ = StyleRegistry.current?.registerStylesheet(PopoverStyle.css)
        Element(
            "div",
            attributes: [
                .attribute("popover", "auto"),
                .id(id),
                .class("swui-popover"),
                .data("placement", placement.rawValue),
            ]
        ) {
            panel
        }
    }
}

public extension HTMLAttribute {
    /// Marks a `<button>` as the invoker of the ``Popover`` with this id.
    static func popoverTarget(_ id: String) -> HTMLAttribute {
        .attribute("popovertarget", id)
    }
}

private struct HoverPopoverModifier<Panel: HTML>: ComponentModifier {
    let placement: PopoverPlacement
    let alignment: PopoverAlignment
    let panel: Panel

    @HTMLBuilder
    func body(content: ModifierContent) -> some HTML {
        let _ = StyleRegistry.current?.registerStylesheet(PopoverStyle.css)
        // anchor-scope keeps one shared anchor name local to each wrapper,
        // so no per-instance identifiers (or style attributes) are needed.
        Element("div", attributes: [.class("swui-hover-anchor")]) {
            content
            Element(
                "div",
                attributes: [
                    .class("swui-hover-popover"),
                    .data("placement", placement.rawValue),
                    .data("alignment", alignment.rawValue),
                    .role("tooltip"),
                ]
            ) {
                panel
            }
        }
    }
}

public extension HTML {
    /// Shows a card while the wrapped element is hovered or focused.
    /// Pure CSS — pair it with a ``Popover`` + `.popoverTarget(_:)` so touch
    /// devices can reach the same content.
    func hoverPopover<Panel: HTML>(
        placement: PopoverPlacement = .top,
        alignment: PopoverAlignment = .center,
        @HTMLBuilder content: () -> Panel
    ) -> some HTML {
        modifier(HoverPopoverModifier(placement: placement, alignment: alignment, panel: content()))
    }
}
