/// A host-neutral cookie value with the attributes SwiftWeb sets on responses.
public struct CookieValue: Sendable, Equatable {
    public enum SameSitePolicy: String, Sendable, Equatable {
        case lax = "Lax"
        case strict = "Strict"
        case none = "None"
    }

    public var string: String
    public var maxAge: Int?
    public var domain: String?
    public var path: String?
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var sameSite: SameSitePolicy?

    public init(
        string: String,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = "/",
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: SameSitePolicy? = .lax
    ) {
        self.string = string
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }

    public func serialized(name: String) -> String {
        var parts = ["\(name)=\(string)"]
        if let maxAge {
            parts.append("Max-Age=\(maxAge)")
        }
        if let domain {
            parts.append("Domain=\(domain)")
        }
        if let path {
            parts.append("Path=\(path)")
        }
        if isSecure {
            parts.append("Secure")
        }
        if isHTTPOnly {
            parts.append("HttpOnly")
        }
        if let sameSite {
            parts.append("SameSite=\(sameSite.rawValue)")
        }
        return parts.joined(separator: "; ")
    }
}

public enum CookieParser {
    /// Parses a `Cookie` request header into name/value pairs.
    public static func parse(cookieHeader: String) -> [String: String] {
        var cookies: [String: String] = [:]
        for pair in cookieHeader.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            let name = parts[0].trimmingWhitespace()
            let value = parts[1].trimmingWhitespace()
            cookies[name] = value
        }
        return cookies
    }
}

extension Substring {
    fileprivate func trimmingWhitespace() -> String {
        String(drop(while: { $0 == " " || $0 == "\t" }).reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }
}
