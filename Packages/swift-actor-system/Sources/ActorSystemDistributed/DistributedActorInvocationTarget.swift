import ActorSystemCore
import Distributed

struct DistributedActorInvocationTarget<Act: DistributedActor>: ActorInvocationTarget, Sendable
where Act.ID == ActorAddress,
      Act.ActorSystem.InvocationDecoder == ActorDistributedInvocationDecoder,
      Act.ActorSystem.ResultHandler == ActorDistributedResultHandler {
    let actor: Act
    let descriptor: ActorTypeDescriptor
    let aliases: ActorTargetAliasTable
    let codecs: ActorDistributedCodecRegistry
    let configuration: ActorSystemConfiguration

    var address: ActorAddress {
        actor.id
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        guard let compilerTarget = aliases.compilerTarget(for: invocation.method) else {
            throw ActorSystemError.targetUnavailable(invocation.method)
        }
        var decoder = try ActorDistributedInvocationDecoder(
            payload: invocation.payload,
            registry: codecs,
            maximumArgumentCount: configuration.maximumCollectionElements,
            maximumNestingDepth: configuration.maximumNestingDepth
        )
        let store = ActorDistributedResultStore()
        let handler = ActorDistributedResultHandler(registry: codecs, store: store)
        try await actor.actorSystem.executeDistributedTarget(
            on: actor,
            target: RemoteCallTarget(compilerTarget),
            invocationDecoder: &decoder,
            handler: handler
        )
        try decoder.requireExhausted()
        guard let outcome = await store.take() else {
            throw ActorSystemError.decodingFailed
        }
        switch outcome {
        case .success(let result):
            return result
        case .applicationFailure(let failure):
            throw failure
        case .systemFailure(let failure):
            throw ActorSystemError.remoteFailure(
                ActorRemoteFailure(code: failure.code.rawValue)
            )
        }
    }
}
