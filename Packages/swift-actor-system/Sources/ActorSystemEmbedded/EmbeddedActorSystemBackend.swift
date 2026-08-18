import ActorSystemCore

/// Generated-registration operations specific to the Embedded projection.
/// Application lifecycle code should depend on `EmbeddedActorSystem` itself.
public struct EmbeddedActorSystemBackend: Sendable {
    private let system: EmbeddedActorSystem

    package init(system: EmbeddedActorSystem) {
        self.system = system
    }

    public func register<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) throws {
        try system.registerBackend(instance, target: target)
    }

    public func registerGenerated<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) {
        system.registerGeneratedBackend(instance, target: target)
    }
}

public extension EmbeddedActorSystem {
    var embeddedBackend: EmbeddedActorSystemBackend {
        EmbeddedActorSystemBackend(system: self)
    }
}
