import SwiftHTML
import SwiftWebUI

struct StoryboardStylesheet: Component {
    var body: some HTML {
        style {
            rawHTML(Self.css)
        }
    }

    static let css = """
    html { scroll-behavior: smooth; }
    body { margin: 0; }

    .storyboard-page {
        --bg: var(--swui-surface);
        --bg-sub: color-mix(in srgb, var(--swui-text-muted) 8%, var(--swui-surface));
        --seg-active: var(--swui-surface-raised);
        --ui-text: var(--swui-text);
        --ui-text-2: var(--swui-text-muted);
        --ui-border: var(--swui-border);
        --ui-accent: var(--swui-accent);
        --ui-accent-soft: color-mix(in srgb, var(--swui-accent) 10%, transparent);
        --code-bg: color-mix(in srgb, var(--swui-text-muted) 7%, var(--swui-surface));
        --code-text: var(--swui-text);
        --shadow: 0 1px 3px rgba(0,0,0,.06), 0 12px 32px rgba(0,0,0,.07);
        height: 100vh;
        min-height: 100vh;
        overflow: hidden;
        background: var(--bg);
        color: var(--ui-text);
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif;
        -webkit-font-smoothing: antialiased;
    }

    .storyboard-page,
    .storyboard-page * {
        box-sizing: border-box;
    }

    .storyboard-page a {
        color: inherit;
    }

    .storyboard-shell {
        height: 100%;
        min-height: 0;
    }

    .storyboard-topbar {
        flex: none;
        z-index: 40;
        min-height: 54px;
        height: 54px;
        border-bottom: 1px solid var(--ui-border);
        padding: 0 18px;
        gap: 14px;
        background: var(--bg);
        align-items: center !important;
        flex-wrap: nowrap !important;
    }

    .storyboard-page .storyboard-topbar-title {
        width: 226px;
        max-width: 226px;
        flex: 0 0 226px !important;
        align-items: center !important;
        gap: 9px !important;
        min-width: 0;
    }

    .storyboard-mark {
        width: 26px;
        height: 26px;
        border-radius: 7px;
        background: linear-gradient(160deg, #65a8ff, #1769e0);
        display: flex;
        align-items: center;
        justify-content: center;
        color: #fff;
        font-weight: 700;
        font-size: 14px;
        box-shadow: 0 2px 6px rgba(23,105,224,.4);
        flex: none;
    }

    .storyboard-product-title {
        font-size: 15px;
        font-weight: 640;
        letter-spacing: 0;
        white-space: nowrap;
    }

    .storyboard-product-badge {
        font-size: 11px;
        color: var(--ui-text-2);
        border: 1px solid var(--ui-border);
        border-radius: 5px;
        padding: 1px 5px;
        white-space: nowrap;
    }

    .storyboard-search {
        flex: 1 1 280px;
        max-width: 280px;
        display: flex;
        align-items: center;
        gap: 8px;
        min-width: 180px;
        background: var(--bg-sub);
        border-radius: 9px;
        padding: 7px 12px;
        color: var(--ui-text-2);
        font-size: 13px;
        line-height: 1;
    }

    .storyboard-search-icon {
        opacity: .6;
    }

    .storyboard-search span:not(.storyboard-search-icon):not(.storyboard-search-shortcut) {
        white-space: nowrap;
    }

    .storyboard-search-shortcut {
        margin-left: auto;
        font-size: 11px;
        border: 1px solid var(--ui-border);
        border-radius: 5px;
        padding: 1px 5px;
        white-space: nowrap;
    }

    .storyboard-topbar-actions {
        margin-left: auto;
        align-items: center !important;
        gap: 16px !important;
        flex-wrap: nowrap !important;
        min-width: 0;
    }

    .storyboard-topbar-link {
        color: var(--ui-text);
        font-size: 13.5px;
        font-weight: 500;
        text-decoration: none;
        white-space: nowrap;
    }

    .storyboard-topbar-link.is-muted {
        color: var(--ui-text-2);
    }

    .storyboard-theme-switcher,
    .storyboard-control-segments {
        display: inline-flex;
        gap: 2px;
        padding: 3px;
        border-radius: 8px;
        background: var(--bg-sub);
        border: 1px solid var(--ui-border);
        flex: none;
    }

    .storyboard-page .storyboard-theme-button,
    .storyboard-page .storyboard-control-segment,
    .storyboard-page .storyboard-control-toggle {
        min-height: 30px;
        height: 30px;
        border: 0;
        border-radius: 6px;
        padding: 0 11px;
        background: transparent;
        color: var(--ui-text);
        font-size: 13px;
        font-weight: 500;
        line-height: 1;
        white-space: nowrap;
        box-shadow: none;
    }

    .storyboard-page .storyboard-theme-button.is-selected,
    .storyboard-page .storyboard-control-segment.is-selected,
    .storyboard-page .storyboard-control-toggle.is-selected {
        background: var(--seg-active);
        box-shadow: 0 1px 2px rgba(0,0,0,.14);
        color: var(--ui-text);
    }

    .storyboard-main {
        flex: 1 1 auto;
        min-height: 0;
        overflow: hidden;
        flex-wrap: nowrap !important;
        align-items: stretch !important;
    }

    .storyboard-page .storyboard-sidebar {
        flex: 0 0 226px !important;
        width: 226px !important;
        max-width: 226px;
        height: 100%;
        overflow-y: auto;
        padding: 14px 12px;
        background: var(--bg);
        border-right: 1px solid var(--ui-border);
        gap: 14px !important;
    }

    .storyboard-sidebar-section {
        margin-bottom: 0;
    }

    .storyboard-sidebar-section-title {
        text-transform: uppercase;
        letter-spacing: .05em;
        font-size: 11px;
        font-weight: 700;
        line-height: 1.2;
        opacity: .7;
        padding: 6px 10px;
        color: var(--ui-text-2);
    }

    .storyboard-sidebar-section-items {
        gap: 2px !important;
    }

    .storyboard-sidebar-link {
        display: block;
        width: 100%;
        min-height: 31px;
        padding: 6px 10px;
        border-radius: 7px;
        color: var(--ui-text-2);
        text-decoration: none;
        white-space: nowrap;
        font-size: 13.5px;
        font-weight: 500;
        line-height: 1.35;
        cursor: pointer;
    }

    .storyboard-sidebar-link:hover {
        background: color-mix(in srgb, var(--ui-text) 6%, transparent);
        color: var(--ui-text);
    }

    .storyboard-sidebar-link.is-selected {
        background: var(--ui-accent-soft);
        color: var(--ui-accent);
        font-weight: 600;
    }

    .storyboard-page .storyboard-detail {
        flex: 1 1 0 !important;
        width: auto !important;
        min-width: 0;
        height: 100%;
        overflow-y: auto;
        display: block;
        padding: 22px 30px;
    }

    .storyboard-detail-content {
        width: min(100%, 760px);
    }

    .storyboard-page .storyboard-inspector {
        flex: 0 0 184px !important;
        width: 184px !important;
        max-width: 184px;
        height: 100%;
        overflow-y: auto;
        padding: 22px 18px;
        border-left: 1px solid var(--ui-border);
        background: var(--bg);
    }

    .storyboard-breadcrumb {
        margin-bottom: 8px;
        font-size: 12px;
        color: var(--ui-text-2);
        line-height: 1.4;
    }

    .storyboard-breadcrumb-separator {
        opacity: .5;
        margin: 0 5px;
    }

    .storyboard-breadcrumb-current {
        color: var(--ui-text);
    }

    .storyboard-title {
        font-size: 25px;
        font-weight: 680;
        line-height: 1.15;
        letter-spacing: 0;
        margin: 0 0 5px;
    }

    .storyboard-description {
        font-size: 14px;
        line-height: 1.5;
        color: var(--ui-text-2);
        margin: 0 0 16px;
    }

    .storyboard-section {
        margin-top: 18px;
    }

    .storyboard-section.bottom {
        margin-bottom: 10px;
    }

    .storyboard-section-title {
        font-size: 12.5px;
        font-weight: 640;
        line-height: 1.3;
        margin-bottom: 7px;
    }

    .storyboard-section-title.tight {
        margin-bottom: 3px;
    }

    .storyboard-section-title.related {
        margin-bottom: 9px;
    }

    .storyboard-section-caption {
        margin-bottom: 8px;
        color: var(--ui-text-2);
        font-size: 12.5px;
        line-height: 1.5;
    }

    .storyboard-preview-frame {
        overflow: hidden;
        border: 1px solid var(--ui-border);
        border-radius: 12px;
        background: var(--bg);
    }

    .storyboard-preview-canvas {
        position: relative;
        min-height: 168px;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        background: var(--bg-sub);
        background-image: radial-gradient(var(--ui-border) 1.1px, transparent 1.1px);
        background-size: 18px 18px;
    }

    .storyboard-preview-root {
        display: flex;
        align-items: center;
        justify-content: center;
        flex-wrap: wrap;
        gap: 14px;
        width: 100%;
    }

    .storyboard-controls {
        border-top: 1px solid var(--ui-border);
        padding: 11px 14px;
        display: flex;
        gap: 18px;
        align-items: center;
        flex-wrap: wrap;
    }

    .storyboard-control {
        display: flex;
        align-items: center;
        gap: 9px;
    }

    .storyboard-control-label {
        font-size: 11px;
        color: var(--ui-text-2);
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: .04em;
        white-space: nowrap;
    }

    .storyboard-control-value {
        min-width: 34px;
        color: var(--ui-text);
        font-family: var(--swui-mono-font-family);
        font-size: 12.5px;
    }

    .storyboard-page .storyboard-control-text .swui-field-label {
        display: none;
    }

    .storyboard-page .storyboard-control-text .swui-text-field {
        width: 170px;
        min-width: 170px;
        background: var(--bg-sub);
    }

    .storyboard-page .storyboard-code-block {
        width: 100%;
        min-width: 0;
        max-width: none;
        margin: 0;
        border: 1px solid var(--ui-border);
        border-radius: 12px;
        overflow: auto;
        background: var(--code-bg);
        color: var(--code-text);
        font-family: var(--swui-mono-font-family);
        font-size: 12.5px;
        line-height: 1.65;
        padding: 14px 0;
    }

    .storyboard-page .storyboard-code-block.rendered {
        font-size: 12px;
        line-height: 1.6;
    }

    .storyboard-page .storyboard-code-block .swui-code-line {
        display: grid;
        grid-template-columns: minmax(2.5ch, auto) 1fr;
        column-gap: 16px;
        padding: 0 18px;
        white-space: pre;
    }

    .storyboard-page .storyboard-code-block .swui-code-line-plain {
        display: block;
        white-space: pre-wrap;
        word-break: break-word;
    }

    .storyboard-page .storyboard-code-block .swui-code-line-number {
        text-align: right;
        user-select: none;
        opacity: .4;
    }

    .storyboard-property-panel {
        overflow: hidden;
        border: 1px solid var(--ui-border);
        border-radius: 12px;
        background: var(--bg);
    }

    .storyboard-property-row {
        border-bottom: 1px solid var(--ui-border);
        padding: 10px 14px;
    }

    .storyboard-property-row:last-child {
        border-bottom: 0;
    }

    .storyboard-page .storyboard-property-name,
    .storyboard-page .storyboard-property-values {
        display: inline-block;
        height: 21px;
        padding-block: 0;
        padding-inline: 6px;
        line-height: 21px;
        vertical-align: middle;
        letter-spacing: 0;
        font-kerning: normal;
        font-feature-settings: "kern" 1, "liga" 0, "calt" 0;
        font-variant-ligatures: none;
        text-rendering: geometricPrecision;
    }

    .storyboard-page .storyboard-property-name {
        color: var(--ui-text);
        font-family: var(--swui-mono-font-family);
        font-size: 12.5px;
        font-weight: 600;
    }

    .storyboard-page .storyboard-property-values {
        color: var(--ui-accent);
        font-family: var(--swui-mono-font-family);
        font-size: 12.5px;
    }

    .storyboard-related-grid {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
    }

    .storyboard-related-link {
        flex: 1 1 170px;
        min-width: 170px;
        border: 1px solid var(--ui-border);
        border-radius: 10px;
        padding: 12px 14px;
        color: var(--ui-text);
        text-decoration: none;
        cursor: pointer;
    }

    .storyboard-related-link .swui-text-muted {
        margin-top: 2px;
        color: var(--ui-text-2);
        font-size: 12.5px;
        line-height: 1.4;
    }

    .storyboard-inspector-title {
        margin-bottom: 12px;
        color: var(--ui-text-2);
        font-size: 11px;
        font-weight: 700;
        line-height: 1.2;
        text-transform: uppercase;
        letter-spacing: .05em;
        opacity: .7;
    }

    .storyboard-inspector-nav {
        gap: 11px !important;
    }

    .storyboard-inspector-link {
        display: block;
        padding-left: 10px;
        color: var(--ui-text-2);
        font-size: 12.5px;
        line-height: 1.35;
    }

    .storyboard-inspector-link.is-selected {
        margin-left: -12px;
        border-left: 2px solid var(--ui-accent);
        color: var(--ui-text);
        font-weight: 600;
    }

    .storyboard-typography-preview {
        width: 100%;
        text-align: center;
        margin: 0;
    }

    .storyboard-centered-demo {
        align-items: center !important;
        justify-content: center;
    }

    .storyboard-grid-demo {
        width: 480px;
        max-width: 82vw;
        display: grid;
        grid-template-columns: repeat(12, 1fr);
        gap: 16px;
        padding: 0 16px;
    }

    .storyboard-grid-pane {
        height: 58px;
        border-radius: 8px;
        background: color-mix(in srgb, var(--ui-accent) 16%, transparent);
        border: 1px solid color-mix(in srgb, var(--ui-accent) 32%, transparent);
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--ui-accent);
        font-family: var(--swui-mono-font-family);
        font-size: 11px;
    }

    .storyboard-grid-pane.span-8 { grid-column: span 8; }
    .storyboard-grid-pane.span-4 { grid-column: span 4; }

    .storyboard-spacing-demo {
        gap: 34px !important;
        align-items: center !important;
        flex-wrap: wrap !important;
        justify-content: center;
    }

    .storyboard-spacing-label {
        width: 34px;
        text-align: right;
    }

    .storyboard-spacing-bar {
        width: 100%;
        height: 16px;
        border-radius: 3px;
        background: color-mix(in srgb, var(--ui-accent) 38%, transparent);
    }

    .storyboard-spacing-bar.is-active {
        background: var(--ui-accent);
    }

    .storyboard-spacing-base-label {
        color: var(--ui-accent);
        font-weight: 640;
    }

    .storyboard-spacing-tile {
        display: grid;
        grid-template-columns: repeat(4, 8px);
        grid-auto-rows: 8px;
        gap: 1px;
        overflow: hidden;
        border: 1px solid var(--ui-border);
        border-radius: 4px;
        background: var(--ui-border);
    }

    .storyboard-spacing-tile > div {
        background: color-mix(in srgb, var(--ui-accent) 12%, var(--bg));
    }

    .storyboard-spacing-grid-label {
        font-size: 12px;
    }

    .storyboard-alignment-frame {
        width: 420px;
        max-width: 80vw;
        height: 120px;
        border: 1.5px dashed var(--ui-border);
        border-radius: 10px;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 0 14px;
    }

    .storyboard-alignment-chip {
        padding: 10px 18px;
        border-radius: 8px;
        background: var(--ui-accent);
        color: var(--swui-accent-text);
        font-size: 13px;
        font-weight: 600;
    }

    .storyboard-responsive-lattice {
        width: 480px;
        max-width: 82vw;
        height: 38px;
        display: grid;
        grid-template-columns: repeat(12, 1fr);
        gap: 22px;
        padding: 0 16px;
        border: 1px solid var(--ui-border);
        border-radius: 6px;
        background: var(--bg);
    }

    .storyboard-responsive-lattice > div {
        background: color-mix(in srgb, var(--ui-accent) 13%, transparent);
        border-left: 1px solid color-mix(in srgb, var(--ui-accent) 28%, transparent);
        border-right: 1px solid color-mix(in srgb, var(--ui-accent) 28%, transparent);
    }

    .storyboard-responsive-content {
        width: 480px;
        max-width: 82vw;
        padding: 0 16px;
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 22px;
    }

    .storyboard-responsive-content > div {
        height: 62px;
        border-radius: 8px;
        background: color-mix(in srgb, var(--ui-accent) 17%, transparent);
        border: 1px solid color-mix(in srgb, var(--ui-accent) 34%, transparent);
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--ui-accent);
        font-family: var(--swui-mono-font-family);
        font-size: 11px;
    }

    .storyboard-phone {
        position: relative;
        width: 188px;
        height: 300px;
        overflow: hidden;
        border: 6px solid var(--ui-text);
        border-radius: 30px;
        background: var(--swui-surface-raised);
        box-shadow: var(--shadow);
    }

    .storyboard-phone-notch {
        position: absolute;
        top: 0;
        left: 50%;
        width: 96px;
        height: 18px;
        transform: translateX(-50%);
        border-radius: 0 0 12px 12px;
        background: #000;
    }

    .storyboard-phone-safe-area {
        position: absolute;
        inset: 30px 8px 18px;
        border: 1.5px dashed color-mix(in srgb, var(--ui-accent) 55%, transparent);
        border-radius: 8px;
        background: color-mix(in srgb, var(--ui-accent) 9%, transparent);
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--ui-accent);
        font-size: 11px;
        font-weight: 640;
    }

    .storyboard-phone-home {
        position: absolute;
        left: 50%;
        bottom: 7px;
        width: 90px;
        height: 4px;
        transform: translateX(-50%);
        border-radius: 2px;
        background: var(--ui-text-2);
        opacity: .6;
    }

    .storyboard-color-swatch {
        width: 150px;
        height: 104px;
        background: #007aff;
    }

    .storyboard-groupbox-demo {
        max-width: 280px;
        padding: 13px;
    }

    .storyboard-divider-demo {
        width: min(100%, 320px);
    }

    @media (max-width: 980px) {
        .storyboard-topbar {
            height: auto;
            min-height: 54px;
            padding: 10px 14px;
            flex-wrap: wrap !important;
        }

        .storyboard-page .storyboard-topbar-title {
            width: auto;
            max-width: none;
            flex: 1 1 220px !important;
        }

        .storyboard-search {
            order: 3;
            flex-basis: 100%;
            max-width: none;
        }

        .storyboard-topbar-actions {
            margin-left: 0;
        }

        .storyboard-main {
            overflow: auto;
        }

        .storyboard-sidebar,
        .storyboard-inspector {
            display: none;
        }

        .storyboard-page .storyboard-detail {
            padding: 22px 18px;
        }
    }
    """
}
