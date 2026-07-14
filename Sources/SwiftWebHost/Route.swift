import HTTPTypes

/// One registered route: the host-neutral record adapters lower onto their router.
public final class Route: Sendable {
    public enum Handler: Sendable {
        case http(@Sendable (Request) async throws -> Response)
        case webSocket(
            shouldUpgrade: @Sendable (Request) async throws -> HTTPFields?,
            onUpgrade: @Sendable (Request, any WebSocketChannel) async -> Void
        )
    }

    public let method: HTTPRequest.Method
    public let path: [PathComponent]
    public let bodyStrategy: BodyStreamStrategy
    public let handler: Handler

    public init(
        method: HTTPRequest.Method,
        path: [PathComponent],
        bodyStrategy: BodyStreamStrategy,
        handler: Handler
    ) {
        self.method = method
        self.path = path
        self.bodyStrategy = bodyStrategy
        self.handler = handler
    }
}

extension Route {
    /// True for plain HTTP handlers (route-table duplicate detection ignores
    /// WebSocket upgrades, which may legitimately share a GET path).
    package var isHTTP: Bool {
        if case .http = handler {
            return true
        }
        return false
    }
}
