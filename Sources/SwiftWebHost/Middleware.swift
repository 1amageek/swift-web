/// Host-neutral middleware placed between the host server and the routed handler,
/// replacing `Vapor.Middleware` for the SwiftWeb core.
/// Class-bound so `any Middleware` remains available on Embedded
/// Swift, whose existentials are limited to class-constrained protocols.
public protocol Middleware: AnyObject, Sendable {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response
}

/// The downstream side of a middleware chain.
/// Class-bound so `any Responder` remains available on Embedded Swift.
public protocol Responder: AnyObject, Sendable {
    func respond(to request: Request) async throws -> Response
}

public final class ClosureResponder: Responder {
    private let handler: @Sendable (Request) async throws -> Response

    public init(_ handler: @escaping @Sendable (Request) async throws -> Response) {
        self.handler = handler
    }

    public func respond(to request: Request) async throws -> Response {
        try await handler(request)
    }
}

private final class MiddlewareResponder: Responder {
    let middleware: any Middleware
    let next: any Responder

    init(middleware: any Middleware, next: any Responder) {
        self.middleware = middleware
        self.next = next
    }

    func respond(to request: Request) async throws -> Response {
        try await middleware.respond(to: request, chainingTo: next)
    }
}

extension Middleware {
    public func makeResponder(chainingTo next: any Responder) -> any Responder {
        MiddlewareResponder(middleware: self, next: next)
    }
}

/// An ordered middleware collection, replacing `Vapor.Middlewares` for the core.
public struct Middlewares: Sendable {
    public private(set) var all: [any Middleware]

    public init() {
        self.all = []
    }

    public mutating func use(_ middleware: any Middleware) {
        all.append(middleware)
    }

    public func makeResponder(chainingTo responder: any Responder) -> any Responder {
        var responder = responder
        for middleware in all.reversed() {
            responder = middleware.makeResponder(chainingTo: responder)
        }
        return responder
    }
}
