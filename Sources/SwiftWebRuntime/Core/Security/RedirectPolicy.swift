#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

public struct RedirectPolicy: Sendable {
    public var origin: OriginPolicy
    public var fallbackPath: String

    public init(
        origin: OriginPolicy = .sameOrigin,
        fallbackPath: String = "/"
    ) {
        self.origin = origin
        self.fallbackPath = fallbackPath
    }

    public static let sameOrigin = RedirectPolicy()

    func validatedLocation(
        _ location: String,
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy
    ) throws -> String {
        guard let location = sanitizedLocation(location, for: request, forwardedHeaders: forwardedHeaders) else {
            throw Abort(.forbidden, reason: "Redirect location is not allowed")
        }
        return location
    }

    func fallbackLocation(
        candidates: [String?],
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy
    ) -> String {
        for candidate in candidates {
            guard let candidate,
                  let location = sanitizedLocation(candidate, for: request, forwardedHeaders: forwardedHeaders) else {
                continue
            }
            return location
        }
        return fallbackPath
    }

    private func sanitizedLocation(
        _ location: String,
        for request: Request,
        forwardedHeaders: ForwardedHeadersPolicy
    ) -> String? {
        let trimmed = location.trimmedWhitespace()
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("/") && !trimmed.hasPrefix("//") {
            return trimmed
        }
        guard let components = URLComponents(string: trimmed),
              components.scheme != nil,
              components.host != nil,
              origin.allows(origin: trimmed, for: request, forwardedHeaders: forwardedHeaders) else {
            return nil
        }
        var path = components.percentEncodedPath
        if path.isEmpty {
            path = "/"
        }
        if let query = components.percentEncodedQuery, !query.isEmpty {
            path += "?\(query)"
        }
        if let fragment = components.percentEncodedFragment, !fragment.isEmpty {
            path += "#\(fragment)"
        }
        return path
    }
}
