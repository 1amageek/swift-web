/// A structural split of a URL reference (RFC 3986 §3) without decoding:
/// components keep their wire (percent-encoded) form. Purpose-built for the
/// security policies (origin normalization, redirect validation) so they
/// behave identically on every profile, including Embedded.
package struct URLReference: Sendable {
    package let scheme: String?
    package let host: String?
    package let port: Int?
    /// Raw path as written (percent escapes preserved).
    package let path: String
    /// Raw query as written, without the leading `?`.
    package let query: String?
    /// Raw fragment as written, without the leading `#`.
    package let fragment: String?

    package init?(parsing string: String) {
        // Reject whitespace and control characters outright — a URL
        // containing them is malformed and must not pass a security check.
        for byte in string.utf8 where byte <= 0x20 || byte == 0x7F {
            return nil
        }

        var rest = Substring(string)

        // scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ":"
        var scheme: String?
        if let colon = rest.firstIndex(of: ":") {
            let candidate = rest[..<colon]
            if let first = candidate.first, first.isLetter,
               candidate.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }),
               !candidate.isEmpty,
               // a colon inside path-only references ("a:b/c" with no "//")
               // still parses as a scheme per RFC; that is the desired
               // behavior for absolute-URL validation.
               !rest[..<colon].contains("/") {
                scheme = candidate.lowercased()
                rest = rest[rest.index(after: colon)...]
            }
        }
        self.scheme = scheme

        // authority: "//" [ userinfo "@" ] host [ ":" port ]
        var host: String?
        var port: Int?
        if rest.hasPrefix("//") {
            rest = rest.dropFirst(2)
            var authorityEnd = rest.endIndex
            for index in rest.indices where rest[index] == "/" || rest[index] == "?" || rest[index] == "#" {
                authorityEnd = index
                break
            }
            var authority = rest[..<authorityEnd]
            rest = rest[authorityEnd...]
            if let at = authority.lastIndex(of: "@") {
                authority = authority[authority.index(after: at)...]
            }
            if authority.hasPrefix("[") {
                // IPv6 literal: [::1]:8080
                guard let close = authority.firstIndex(of: "]") else {
                    return nil
                }
                host = authority[...close].lowercased()
                let afterBracket = authority[authority.index(after: close)...]
                if afterBracket.hasPrefix(":") {
                    guard let parsed = Int(afterBracket.dropFirst()), parsed >= 0 else {
                        return nil
                    }
                    port = parsed
                } else if !afterBracket.isEmpty {
                    return nil
                }
            } else if let colon = authority.lastIndex(of: ":") {
                guard let parsed = Int(authority[authority.index(after: colon)...]), parsed >= 0 else {
                    return nil
                }
                host = authority[..<colon].lowercased()
                port = parsed
            } else {
                host = authority.lowercased()
            }
            if host?.isEmpty == true {
                host = nil
            }
        }
        self.host = host
        self.port = port

        // path / query / fragment
        var path = rest
        var query: Substring?
        var fragment: Substring?
        if let hash = path.firstIndex(of: "#") {
            fragment = path[path.index(after: hash)...]
            path = path[..<hash]
        }
        if let questionMark = path.firstIndex(of: "?") {
            query = path[path.index(after: questionMark)...]
            path = path[..<questionMark]
        }
        self.path = String(path)
        self.query = query.map(String.init)
        self.fragment = fragment.map(String.init)
    }
}
