import HTTPTypes

/// The registration surface the SwiftWeb core lowers routes onto,
/// replacing `Vapor.RoutesBuilder`.
public protocol WebRoutesBuilder: Sendable {
    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [WebPathComponent],
        body: WebBodyStreamStrategy,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute

    @discardableResult
    func webSocket(
        _ path: [WebPathComponent],
        shouldUpgrade: @escaping @Sendable (WebRequest) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (WebRequest, any WebSocketChannel) async -> Void
    ) -> WebRoute

    func grouped(_ path: [WebPathComponent]) -> any WebRoutesBuilder
}

extension WebRoutesBuilder {
    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: [WebPathComponent],
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(method, path, body: .collect, use: handler)
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: WebPathComponent...,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(method, path, body: .collect, use: handler)
    }

    @discardableResult
    public func get(
        _ path: [WebPathComponent],
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(.get, path, body: .collect, use: handler)
    }

    @discardableResult
    public func get(
        _ path: WebPathComponent...,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(.get, path, body: .collect, use: handler)
    }

    @discardableResult
    public func post(
        _ path: [WebPathComponent],
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(.post, path, body: .collect, use: handler)
    }

    @discardableResult
    public func post(
        _ path: WebPathComponent...,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        on(.post, path, body: .collect, use: handler)
    }
}
