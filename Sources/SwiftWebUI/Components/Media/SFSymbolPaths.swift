import Foundation

/// Inline SVG markup for the SF Symbol identifiers SwiftWebUI can render on the
/// web. The web has no access to the SF Symbols font, so `Image(systemName:)`
/// draws an approximating 24×24 glyph (`fill="currentColor"`, so it inherits the
/// surrounding text color) for any identifier listed here, and falls back to the
/// humanised name for anything that is not.
enum SFSymbolPaths {
    /// Maps an SF Symbol identifier to the inner markup of a `0 0 24 24` SVG.
    static let markup: [String: String] = [
        "star.fill": #"<path d="M12 2.5l2.9 5.9 6.6.9-4.8 4.6 1.1 6.5L12 17.8 6.2 20.9l1.1-6.5L2.5 9.8l6.6-.9z"/>"#,
        "bell.badge": #"<path d="M12 3a5 5 0 00-5 5c0 4-1.5 5.5-2 6h14c-.5-.5-2-2-2-6a5 5 0 00-5-5z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M10 19a2 2 0 004 0" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="18" cy="6" r="3"/>"#,
        "gearshape": #"<path d="M12 8.5a3.5 3.5 0 100 7 3.5 3.5 0 000-7z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" stroke="currentColor" stroke-width="1.6"/>"#,
        "gear": #"<path d="M12 8.5a3.5 3.5 0 100 7 3.5 3.5 0 000-7z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" stroke="currentColor" stroke-width="1.6"/>"#,
        "heart.fill": #"<path d="M12 21s-7-4.5-9.5-9C1 9 2.5 5.5 6 5.5c2 0 3.2 1.2 4 2.3.8-1.1 2-2.3 4-2.3 3.5 0 5 3.5 3.5 6.5C19 16.5 12 21 12 21z"/>"#,
        "pin.fill": #"<path d="M12 2c-3.3 0-6 2.5-6 6 0 4.5 6 12 6 12s6-7.5 6-12c0-3.5-2.7-6-6-6z"/><circle cx="12" cy="8" r="2.2" fill="var(--swui-surface-raised)"/>"#,
        "checkmark.seal.fill": #"<path d="M12 2l2.3 1.7 2.8-.3 1.1 2.6 2.4 1.5-.6 2.8 1.3 2.5-2 2-.3 2.8-2.7.8L13 22l-1-2-2.9.2-1.4-2.4-2.7-.9.2-2.8-1.7-2.3 1.7-2.3-.2-2.8 2.7-.9L9 2l3 .9z"/><path d="M8.5 12l2.4 2.4 4.6-4.8" fill="none" stroke="var(--swui-surface-raised)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>"#,
        "envelope": #"<rect x="3" y="5.5" width="18" height="13" rx="2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M4 7l8 5.5L20 7" fill="none" stroke="currentColor" stroke-width="1.6"/>"#,
        "doc.text": #"<path d="M6 3h8l4 4v14H6z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M9 11h6M9 14h6M9 17h4" stroke="currentColor" stroke-width="1.6"/>"#,
        "photo": #"<rect x="3" y="5" width="18" height="14" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="8.4" cy="10" r="1.7"/><path d="M4.5 17.5l4.5-4.2 3 2.4 3.2-3.4 4.3 4.1" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>"#,
        "chart.bar": #"<rect x="3.5" y="13" width="3.6" height="6.5" rx="1"/><rect x="10.2" y="8" width="3.6" height="11.5" rx="1"/><rect x="16.9" y="4.5" width="3.6" height="15" rx="1"/>"#,
        "person.crop.circle": #"<circle cx="12" cy="12" r="9.3" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="12" cy="10" r="3"/><path d="M6.4 18.6c1.1-2.4 3.2-3.7 5.6-3.7s4.5 1.3 5.6 3.7" fill="none" stroke="currentColor" stroke-width="1.6"/>"#
    ]
}
