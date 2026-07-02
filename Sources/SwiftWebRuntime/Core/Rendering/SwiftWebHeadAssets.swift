import SwiftWebStyle

enum SwiftWebHeadAssets {
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
