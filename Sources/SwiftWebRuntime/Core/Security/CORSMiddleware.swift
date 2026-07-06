import HTTPTypes
import SwiftWebHostKit

/// Host-neutral CORS middleware with the same header semantics as Vapor's
/// `CORSMiddleware`, driven by SwiftWeb's `OriginPolicy`.
struct CORSMiddleware: Middleware {
    let originPolicy: OriginPolicy
    let forwardedHeaders: ForwardedHeadersPolicy
    let allowedMethods: String
    let allowedHeaders: String
    let exposedHeaders: String?
    let allowsCredentials: Bool
    let cacheExpiration: Int?

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        guard let requestOrigin = request.headers[.origin] else {
            return try await next.respond(to: request)
        }

        let isPreflight = request.method == .options && request.headers[.accessControlRequestMethod] != nil
        var response = isPreflight ? Response() : try await next.respond(to: request)

        let allowedOrigin = originPolicy.allows(
            origin: requestOrigin,
            for: request,
            forwardedHeaders: forwardedHeaders
        ) ? requestOrigin : ""

        if !allowedOrigin.isEmpty {
            response.headers[.accessControlAllowOrigin] = allowedOrigin
        }
        response.headers[.accessControlAllowMethods] = allowedMethods
        response.headers[.accessControlAllowHeaders] = allowedHeaders
        if let exposedHeaders {
            response.headers[.accessControlExposeHeaders] = exposedHeaders
        }
        if let cacheExpiration {
            response.headers[.accessControlMaxAge] = String(cacheExpiration)
        }
        if allowsCredentials {
            response.headers[.accessControlAllowCredentials] = "true"
        }
        // The allowed origin is derived from the request origin, so caches must
        // key on it.
        if !allowedOrigin.isEmpty {
            response.headers[.vary] = "origin"
        }
        return response
    }
}
