import ActorSystemCore

public struct SwiftWebHTTPActorRouter: ActorRouter {
    public let endpoint: ActorEndpoint

    public init(endpoint: ActorEndpoint = .swiftWebHTTP) {
        self.endpoint = endpoint
    }

    public func route(to recipient: ActorAddress) async throws -> ActorRoute {
        ActorRoute(transport: .swiftWebHTTP, endpoint: endpoint)
    }
}
