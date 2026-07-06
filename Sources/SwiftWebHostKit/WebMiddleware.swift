/// Host-neutral middleware placed between the host server and the routed handler,
/// replacing `Vapor.Middleware` for the SwiftWeb core.
public protocol WebMiddleware: Sendable {
    func respond(to request: WebRequest, chainingTo next: any WebResponder) async throws -> WebResponse
}

/// The downstream side of a middleware chain.
public protocol WebResponder: Sendable {
    func respond(to request: WebRequest) async throws -> WebResponse
}

public struct WebClosureResponder: WebResponder {
    private let handler: @Sendable (WebRequest) async throws -> WebResponse

    public init(_ handler: @escaping @Sendable (WebRequest) async throws -> WebResponse) {
        self.handler = handler
    }

    public func respond(to request: WebRequest) async throws -> WebResponse {
        try await handler(request)
    }
}

private struct WebMiddlewareResponder: WebResponder {
    let middleware: any WebMiddleware
    let next: any WebResponder

    func respond(to request: WebRequest) async throws -> WebResponse {
        try await middleware.respond(to: request, chainingTo: next)
    }
}

extension WebMiddleware {
    public func makeResponder(chainingTo next: any WebResponder) -> any WebResponder {
        WebMiddlewareResponder(middleware: self, next: next)
    }
}

/// An ordered middleware collection, replacing `Vapor.Middlewares` for the core.
public struct WebMiddlewares: Sendable {
    public private(set) var all: [any WebMiddleware]

    public init() {
        self.all = []
    }

    public mutating func use(_ middleware: any WebMiddleware) {
        all.append(middleware)
    }

    public func makeResponder(chainingTo responder: any WebResponder) -> any WebResponder {
        var responder = responder
        for middleware in all.reversed() {
            responder = middleware.makeResponder(chainingTo: responder)
        }
        return responder
    }
}
