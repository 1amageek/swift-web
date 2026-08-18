import ActorSystemCore
import Distributed

public struct ActorDistributedResultHandler: DistributedTargetInvocationResultHandler, Sendable {
    public typealias SerializationRequirement = Codable & Sendable

    let registry: ActorDistributedCodecRegistry
    let store: ActorDistributedResultStore

    public func onReturn<Success>(value: Success) async throws
    where Success: Codable & Sendable {
        let payload = try registry.encode(value)
        try await store.store(.success(ActorInvocationResult(payload: payload)))
    }

    public func onReturnVoid() async throws {
        try await store.store(.success(ActorInvocationResult()))
    }

    public func onThrow<Failure>(error: Failure) async throws where Failure: Error {
        guard let encoded = try registry.encodeDynamicIfRegistered(
            error,
            swiftType: Failure.self
        ) else {
            try await store.store(
                .systemFailure(
                    ActorSystemFailure(code: .remoteFailure)
                )
            )
            return
        }
        try await store.store(
            .applicationFailure(
                ActorApplicationFailure(
                    typeID: encoded.typeID,
                    payload: encoded.payload
                )
            )
        )
    }
}

actor ActorDistributedResultStore {
    private var outcome: ActorInvocationOutcome?

    func store(_ outcome: ActorInvocationOutcome) throws {
        guard self.outcome == nil else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("A distributed invocation produced more than one result")
            )
        }
        self.outcome = outcome
    }

    func take() -> ActorInvocationOutcome? {
        defer { outcome = nil }
        return outcome
    }
}
