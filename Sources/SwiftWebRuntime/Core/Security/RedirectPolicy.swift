#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
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
        guard let reference = URLReference(parsing: trimmed),
              reference.scheme != nil,
              reference.host != nil,
              origin.allows(origin: trimmed, for: request, forwardedHeaders: forwardedHeaders) else {
            return nil
        }
        var path = reference.path
        if path.isEmpty {
            path = "/"
        }
        if let query = reference.query, !query.isEmpty {
            path += "?\(query)"
        }
        if let fragment = reference.fragment, !fragment.isEmpty {
            path += "#\(fragment)"
        }
        return path
    }
}
