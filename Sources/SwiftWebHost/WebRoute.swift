import HTTPTypes

/// One registered route: the host-neutral record adapters lower onto their router.
public final class WebRoute: Sendable {
    public enum Handler: Sendable {
        case http(@Sendable (WebRequest) async throws -> WebResponse)
        case webSocket(
            shouldUpgrade: @Sendable (WebRequest) async throws -> HTTPFields?,
            onUpgrade: @Sendable (WebRequest, any WebSocketChannel) async -> Void
        )
    }

    public let method: HTTPRequest.Method
    public let path: [WebPathComponent]
    public let bodyStrategy: WebBodyStreamStrategy
    public let handler: Handler

    public init(
        method: HTTPRequest.Method,
        path: [WebPathComponent],
        bodyStrategy: WebBodyStreamStrategy,
        handler: Handler
    ) {
        self.method = method
        self.path = path
        self.bodyStrategy = bodyStrategy
        self.handler = handler
    }
}
