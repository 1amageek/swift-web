import SwiftHTML
import SwiftWebStyle

enum SwiftWebHeadAssets {
    /// Applies the document style bootstrap to a rendered page: registers the
    /// provider's stylesheet and scripts so the head markers pick them up, and
    /// stamps the root attributes onto the document `<body>` tag.
    static func applyDocumentStyle(
        to html: String,
        registry: StyleRegistry,
        document: DocumentStyle
    ) -> String {
        guard document.bootstrapRequired,
            let provider = DocumentStyleBootstrap.installed
        else {
            return html
        }
        registry.registerStylesheet(provider.stylesheet)
        for script in provider.scripts {
            registry.registerScript(id: script.id, body: script.body)
        }

        guard let bodyStart = html.firstRangeOfSubstring("<body"),
            let tagEnd = html[bodyStart.upperBound...].firstRangeOfSubstring(">")
        else {
            return html
        }

        var openTag = String(html[bodyStart.lowerBound..<tagEnd.lowerBound])
        let rootClass = escapedAttribute(provider.rootClass)
        if let classRange = openTag.firstRangeOfSubstring(" class=\"") {
            openTag.replaceSubrange(classRange, with: " class=\"\(rootClass) ")
        } else {
            openTag += " class=\"\(rootClass)\""
        }
        if let scheme = document.preferredColorScheme?.rawValue {
            openTag += " data-color-scheme=\"\(escapedAttribute(scheme))\""
        }
        openTag += " data-theme=\"\(escapedAttribute(provider.themeID))\""
        var output = html
        output.replaceSubrange(bodyStart.lowerBound..<tagEnd.lowerBound, with: openTag)
        return output
    }

    /// Applies the document style bootstrap to one streamed chunk: registers
    /// the provider's assets so the chunk's inline styles carry them, and wraps
    /// the fragment in a scoped root so palette variables resolve. Streamed
    /// fragments are not full documents, so the root is a wrapper element
    /// rather than `<body>` attributes.
    static func applyStreamedDocumentStyle(
        to html: String,
        registry: StyleRegistry,
        document: DocumentStyle
    ) -> String {
        guard document.bootstrapRequired,
            let provider = DocumentStyleBootstrap.installed
        else {
            return html
        }
        registry.registerStylesheet(provider.stylesheet)
        for script in provider.scripts {
            registry.registerScript(id: script.id, body: script.body)
        }
        var attributes = " class=\"\(escapedAttribute(provider.rootClass))\""
        if let scheme = document.preferredColorScheme?.rawValue {
            attributes += " data-color-scheme=\"\(escapedAttribute(scheme))\""
        }
        attributes += " data-theme=\"\(escapedAttribute(provider.themeID))\""
        return "<div\(attributes)>\(html)</div>"
    }

    static func assets(from registry: StyleRegistry, nonce: String?) -> String {
        baseStyle(from: registry, nonce: nonce)
            + atomicStyle(from: registry, nonce: nonce)
            + scripts(from: registry, nonce: nonce)
    }

    static func baseStyle(from registry: StyleRegistry, nonce: String?) -> String {
        renderStyle(id: "swui-base", css: registry.stylesheets().joined(), nonce: nonce)
    }

    static func atomicStyle(from registry: StyleRegistry, nonce: String?) -> String {
        let css = registry.rules().map { ".\($0.className) { \($0.body) }" }.joined()
        return renderStyle(id: "swui-atomic", css: css, nonce: nonce)
    }

    static func scripts(from registry: StyleRegistry, nonce: String?) -> String {
        registry.scripts()
            .map { renderScript(id: $0.id, body: $0.body, nonce: nonce) }
            .joined()
    }

    private static func renderStyle(id: String, css: String, nonce: String?) -> String {
        let nonceAttribute = nonce.map { " nonce=\"\(escapedAttribute($0))\"" } ?? ""
        return "<style id=\"\(escapedAttribute(id))\"\(nonceAttribute)>\(css)</style>"
    }

    private static func renderScript(id: String, body: String, nonce: String?) -> String {
        let nonceAttribute = nonce.map { " nonce=\"\(escapedAttribute($0))\"" } ?? ""
        return "<script id=\"\(escapedAttribute(id))\"\(nonceAttribute)>\(body)</script>"
    }

    private static func escapedAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
