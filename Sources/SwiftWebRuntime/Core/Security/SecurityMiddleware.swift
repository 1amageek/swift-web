import Vapor

struct SecurityMiddleware: Middleware {
    let configuration: SecurityConfiguration

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let context = configuration.makeRequestContext(for: request)
        request.securityContext = context
        let response = try await next.respond(to: request)
        if let token = context.csrfToken, context.shouldSetCSRFCookie {
            response.cookies[configuration.csrf.cookieName] = configuration.csrf.cookieValue(token: token)
        }
        configuration.headers.apply(
            to: response,
            request: request,
            context: context,
            forwardedHeaders: configuration.forwardedHeaders
        )
        return response
    }
}
