import ActorSystemCore
import Distributed

public struct DistributedActorTypeRegistration<Act: DistributedActor>: Sendable
where Act.ID == ActorAddress,
      Act.ActorSystem.InvocationDecoder == ActorDistributedInvocationDecoder,
      Act.ActorSystem.ResultHandler == ActorDistributedResultHandler {
    public let actorType: Act.Type
    public let descriptor: ActorTypeDescriptor
    public let aliases: ActorTargetAliasTable

    public init(
        _ actorType: Act.Type,
        descriptor: ActorTypeDescriptor,
        aliases: ActorTargetAliasTable
    ) {
        self.actorType = actorType
        self.descriptor = descriptor
        self.aliases = aliases
    }

    public func eraseToAnyRegistration() -> AnyDistributedActorTypeRegistration {
        AnyDistributedActorTypeRegistration(self)
    }
}

public struct AnyDistributedActorTypeRegistration: Sendable {
    let swiftTypeID: ObjectIdentifier
    let descriptor: ActorTypeDescriptor
    let aliases: ActorTargetAliasTable
    private let makeInvocationTarget: @Sendable (
        any DistributedActor,
        ActorDistributedCodecRegistry,
        ActorSystemConfiguration
    ) -> any ActorInvocationTarget

    public init<Act>(_ registration: DistributedActorTypeRegistration<Act>)
    where Act: DistributedActor,
          Act.ID == ActorAddress,
          Act.ActorSystem.InvocationDecoder == ActorDistributedInvocationDecoder,
          Act.ActorSystem.ResultHandler == ActorDistributedResultHandler {
        self.swiftTypeID = ObjectIdentifier(Act.self)
        self.descriptor = registration.descriptor
        self.aliases = registration.aliases
        self.makeInvocationTarget = { actor, codecs, configuration in
            guard let typed = actor as? Act else {
                preconditionFailure("Distributed actor registration type mismatch")
            }
            return DistributedActorInvocationTarget(
                actor: typed,
                descriptor: registration.descriptor,
                aliases: registration.aliases,
                codecs: codecs,
                configuration: configuration
            )
        }
    }

    func makeTarget(
        actor: any DistributedActor,
        codecs: ActorDistributedCodecRegistry,
        configuration: ActorSystemConfiguration
    ) -> any ActorInvocationTarget {
        makeInvocationTarget(actor, codecs, configuration)
    }
}
