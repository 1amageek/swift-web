import HTTPTypes

/// The registration surface the SwiftWeb core lowers routes onto,
/// replacing `Vapor.RoutesBuilder`.
/// Class-bound so `any RoutesBuilder` (used by macro-generated route
/// registration) remains available on Embedded Swift.
public protocol RoutesBuilder: AnyObject, Sendable {
    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: BodyStreamStrategy,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route

    @discardableResult
    func webSocket(
        _ path: [PathComponent],
        shouldUpgrade: @escaping @Sendable (Request) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (Request, any WebSocketChannel) async -> Void
    ) -> Route

    func grouped(_ path: [PathComponent]) -> any RoutesBuilder
}

extension RoutesBuilder {
    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(method, path, body: .collect, use: handler)
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: PathComponent...,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(method, path, body: .collect, use: handler)
    }

    @discardableResult
    public func get(
        _ path: [PathComponent],
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(.get, path, body: .collect, use: handler)
    }

    @discardableResult
    public func get(
        _ path: PathComponent...,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(.get, path, body: .collect, use: handler)
    }

    @discardableResult
    public func post(
        _ path: [PathComponent],
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(.post, path, body: .collect, use: handler)
    }

    @discardableResult
    public func post(
        _ path: PathComponent...,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        on(.post, path, body: .collect, use: handler)
    }
}
