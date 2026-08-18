import ActorSystemCore

/// Routes actor calls through one connected binary WebSocket channel without
/// exposing WebSocket details to generated actor proxies.
public struct SwiftWebWebSocketActorRouter: ActorRouter {
    public let endpoint: ActorEndpoint

    public init(endpoint: ActorEndpoint = .swiftWebWebSocket) {
        self.endpoint = endpoint
    }

    public func route(to recipient: ActorAddress) async throws -> ActorRoute {
        ActorRoute(transport: .swiftWebWebSocket, endpoint: endpoint)
    }
}
