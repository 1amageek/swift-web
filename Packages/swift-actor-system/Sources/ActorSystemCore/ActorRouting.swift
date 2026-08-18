public struct ActorRoute: Hashable, Sendable {
    public let transport: ActorTransportID
    public let endpoint: ActorEndpoint

    public init(transport: ActorTransportID, endpoint: ActorEndpoint) {
        self.transport = transport
        self.endpoint = endpoint
    }
}

public protocol ActorRouter: Sendable {
    func route(to recipient: ActorAddress) async throws -> ActorRoute
}

public struct RejectingActorRouter: ActorRouter {
    public init() {}

    public func route(to recipient: ActorAddress) async throws -> ActorRoute {
        throw ActorSystemError.routeNotFound(recipient)
    }
}
