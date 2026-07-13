#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

public struct OriginPolicy: Sendable {
    public var allowsSameOrigin: Bool
    public var allowedOrigins: Set<String>

    public init(
        allowsSameOrigin: Bool = true,
        allowedOrigins: Set<String> = []
    ) {
        self.allowsSameOrigin = allowsSameOrigin
        self.allowedOrigins = Set(allowedOrigins.compactMap(Self.normalizedOrigin))
    }

    public static let sameOrigin = OriginPolicy()

    public func allows(
        origin: String,
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy = .ignore
    ) -> Bool {
        guard let normalizedOrigin = Self.normalizedOrigin(origin) else {
            return false
        }
        if allowedOrigins.contains(normalizedOrigin) {
            return true
        }
        guard allowsSameOrigin, let targetOrigin = Self.requestOrigin(for: request, forwardedHeaders: forwardedHeaders) else {
            return false
        }
        return normalizedOrigin == targetOrigin
    }

    func allowsRequestOrigin(_ request: Request, forwardedHeaders: ForwardedHeadersPolicy) -> Bool {
        if let origin = request.headers[.origin] {
            return allows(origin: origin, for: request, forwardedHeaders: forwardedHeaders)
        }
        if let referrer = request.headers[HTTPField.Name("Referer")!] {
            return allows(referrer: referrer, for: request, forwardedHeaders: forwardedHeaders)
        }
        return true
    }

    func allows(
        referrer: String,
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy = .ignore
    ) -> Bool {
        guard let referrerOrigin = Self.normalizedOrigin(referrer) else {
            return false
        }
        if allowedOrigins.contains(referrerOrigin) {
            return true
        }
        guard allowsSameOrigin, let targetOrigin = Self.requestOrigin(for: request, forwardedHeaders: forwardedHeaders) else {
            return false
        }
        return referrerOrigin == targetOrigin
    }

    static func requestOrigin(
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy = .ignore
    ) -> String? {
        let scheme = forwardedHeaders.scheme(for: request) ?? "http"
        let host = forwardedHeaders.host(for: request)
        guard let host else {
            return nil
        }
        return normalizedOrigin("\(scheme)://\(host)")
    }

    static func normalizedOrigin(_ value: String) -> String? {
        guard var components = URLComponents(string: value.trimmedWhitespace()),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        let port = components.port
        components.scheme = scheme
        components.host = host
        components.path = ""
        components.query = nil
        components.fragment = nil
        if (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
            components.port = nil
        }
        return components.string
    }

}
