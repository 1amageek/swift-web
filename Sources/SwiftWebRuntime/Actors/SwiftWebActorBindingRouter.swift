import ActorSystemCore
import Synchronization

/// An actor router whose address-to-route table is supplied by deployment
/// binding data during runtime bootstrap.
public final class SwiftWebActorBindingRouter: ActorRouter, Sendable {
    private let routes = Mutex<[ActorAddress: ActorRoute]>([:])
    private let fallback: (any ActorRouter)?

    public init(fallback: (any ActorRouter)? = nil) {
        self.fallback = fallback
    }

    /// Atomically replaces the active deployment routes.
    ///
    /// Repeating the same address and route is idempotent. Two different
    /// routes for one address are rejected so materialization cannot silently
    /// select a destination based on input order.
    public func replaceRoutes(
        with records: [SwiftWebActorRouteBindingRecord]
    ) throws {
        let next = try validatedRoutes(records)
        routes.withLock { $0 = next }
    }

    /// Adds deployment routes discovered while the scene tree binds concrete
    /// actor identities. Existing equal routes are idempotent; conflicts fail.
    public func mergeRoutes(
        _ records: [SwiftWebActorRouteBindingRecord]
    ) throws {
        let additions = try validatedRoutes(records)
        try routes.withLock { routes in
            for (address, route) in additions {
                if let existing = routes[address], existing != route {
                    throw SwiftWebActorRouteBindingError.conflictingRoutes(
                        actorID: address,
                        first: existing,
                        second: route
                    )
                }
                routes[address] = route
            }
        }
    }

    private func validatedRoutes(
        _ records: [SwiftWebActorRouteBindingRecord]
    ) throws -> [ActorAddress: ActorRoute] {
        var next: [ActorAddress: ActorRoute] = [:]
        for record in records {
            guard !record.actorID.identity.isEmpty else {
                throw SwiftWebActorRouteBindingError.emptyActorIdentity(
                    actorType: record.actorID.type
                )
            }
            guard !record.route.transport.rawValue.isEmpty else {
                throw SwiftWebActorRouteBindingError.emptyTransport(
                    actorID: record.actorID
                )
            }
            guard !record.route.endpoint.transportSpecificAddress.isEmpty else {
                throw SwiftWebActorRouteBindingError.emptyEndpoint(
                    actorID: record.actorID
                )
            }
            if let existing = next[record.actorID], existing != record.route {
                throw SwiftWebActorRouteBindingError.conflictingRoutes(
                    actorID: record.actorID,
                    first: existing,
                    second: record.route
                )
            }
            next[record.actorID] = record.route
        }
        return next
    }

    public func route(to recipient: ActorAddress) async throws -> ActorRoute {
        if let route = routes.withLock({ $0[recipient] }) {
            return route
        }
        guard let fallback else {
            throw ActorSystemError.routeNotFound(recipient)
        }
        return try await fallback.route(to: recipient)
    }
}

public enum SwiftWebActorRouteBindingError: Error, Sendable, Equatable {
    case emptyActorIdentity(actorType: ActorTypeID)
    case emptyTransport(actorID: ActorAddress)
    case emptyEndpoint(actorID: ActorAddress)
    case conflictingRoutes(
        actorID: ActorAddress,
        first: ActorRoute,
        second: ActorRoute
    )
}
