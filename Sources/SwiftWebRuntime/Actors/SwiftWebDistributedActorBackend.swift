#if SWIFTWEB_ACTORS
import ActorSystemCore
import ActorSystemDistributed

/// Native and standard-WASM registration capabilities that are intentionally
/// outside the profile-neutral `WebActorSystem` lifecycle surface.
public struct SwiftWebDistributedActorBackend: Sendable {
    private let implementation: SwiftActorSystem

    package init(implementation: SwiftActorSystem) {
        self.implementation = implementation
    }

    public func registerGeneratedBootstrap(
        _ bootstrap: any SwiftActorSystemBootstrap.Type
    ) throws {
        try implementation.registerBootstrap(bootstrap)
    }

    public func registerCodec<Value: Codable & Sendable>(
        _ type: Value.Type,
        typeID: ActorTypeID,
        codec: ActorGeneratedCodec<Value>
    ) throws {
        try implementation.registerCodec(type, typeID: typeID, codec: codec)
    }

    public func register(
        _ registration: AnyDistributedActorTypeRegistration
    ) throws {
        try implementation.register(registration)
    }
}
#endif
