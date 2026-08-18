import ActorSystemCore

/// One atomic module registration for the Distributed adapter.
///
/// `actorTypeDescriptors` is the authoritative set owned by this bootstrap.
/// Registration fails and rolls back unless `register(in:)` registers exactly
/// that actor set and every method parameter, result, and error type ID has a
/// codec by the end of the bootstrap body.
public protocol SwiftActorSystemBootstrap: ActorSchemaModule {
    static var bootstrapIdentifier: String { get }
    static var dependencies: [any SwiftActorSystemBootstrap.Type] { get }

    static func register(in actorSystem: SwiftActorSystem) throws
}

public extension SwiftActorSystemBootstrap {
    static var bootstrapIdentifier: String {
        String(reflecting: Self.self)
    }

    static var dependencies: [any SwiftActorSystemBootstrap.Type] {
        []
    }
}
