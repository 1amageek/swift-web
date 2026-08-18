import ActorSystemCore

public struct StaticActorRouter: ActorRouter, Sendable {
    private let routes: [ActorTypeID: ActorRoute]

    public init(routes: [ActorTypeID: ActorRoute]) {
        self.routes = routes
    }

    public func route(to recipient: ActorAddress) async throws -> ActorRoute {
        guard let route = routes[recipient.type] else {
            throw ActorSystemError.routeNotFound(recipient)
        }
        return route
    }
}
