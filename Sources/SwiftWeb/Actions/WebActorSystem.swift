@preconcurrency import ActorRuntime
@preconcurrency import Distributed
import Foundation

public final class WebActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = String
    public typealias InvocationEncoder = WebActorInvocationEncoder
    public typealias InvocationDecoder = WebActorInvocationDecoder
    public typealias ResultHandler = WebActorResultHandler
    public typealias SerializationRequirement = Codable & Sendable

    public static let shared = WebActorSystem()

    private let registry = ActorRegistry()

    public init() {}

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID where Act: DistributedActor {
        "\(String(reflecting: actorType)):\(UUID().uuidString)"
    }

    public func actorReady<Act>(_ actor: Act) where Act: DistributedActor, Act.ID == ActorID {
        registry.register(actor, id: actor.id)
    }

    public func resignID(_ id: ActorID) {
        registry.unregister(id: id)
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorID {
        registry.find(id: id) as? Act
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        WebActorInvocationEncoder()
    }

    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res where Act: DistributedActor, Act.ID == ActorID, Err: Error, Res: Codable & Sendable {
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
        let response = try await execute(envelope: envelope, target: target)

        switch response.result {
        case .success(let data):
            return try JSONDecoder().decode(Res.self, from: data)
        case .void:
            guard Res.self == Void.self else {
                throw RuntimeError.executionFailed("Expected \(Res.self), but invocation returned Void", underlying: "Type mismatch")
            }
            return () as! Res
        case .failure(let error):
            throw error
        }
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws where Act: DistributedActor, Act.ID == ActorID, Err: Error {
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
        let response = try await execute(envelope: envelope, target: target)

        switch response.result {
        case .void:
            return
        case .success:
            throw RuntimeError.executionFailed("Expected Void, but invocation returned a value", underlying: "Type mismatch")
        case .failure(let error):
            throw error
        }
    }

    public func invoke(
        actorID: ActorID,
        targetIdentifier: String,
        arguments: [Data]
    ) async throws -> ResponseEnvelope {
        let envelope = InvocationEnvelope(
            recipientID: actorID,
            target: targetIdentifier,
            arguments: arguments
        )
        return try await execute(
            envelope: envelope,
            target: RemoteCallTarget(targetIdentifier)
        )
    }

    public func shutdown() {
        registry.clear()
    }

    private func execute(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget
    ) async throws -> ResponseEnvelope {
        guard let actor = registry.find(id: envelope.recipientID) else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }

        var decoder = try WebActorInvocationDecoder(envelope: envelope)
        let resultStore = WebActorInvocationResultStore()
        let handler = WebActorResultHandler(callID: envelope.callID) { response in
            await resultStore.store(response)
        }

        try await executeDistributedTarget(
            on: actor,
            target: target,
            invocationDecoder: &decoder,
            handler: handler
        )

        guard let response = await resultStore.response else {
            throw RuntimeError.executionFailed("No result captured", underlying: "Unknown")
        }
        return response
    }
}

private actor WebActorInvocationResultStore {
    private var storedResponse: ResponseEnvelope?

    var response: ResponseEnvelope? {
        storedResponse
    }

    func store(_ response: ResponseEnvelope) {
        storedResponse = response
    }
}
