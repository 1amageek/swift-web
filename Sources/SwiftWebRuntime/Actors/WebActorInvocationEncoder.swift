#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime
@preconcurrency import Distributed

public struct WebActorInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = Codable & Sendable

    private var base = CodableInvocationEncoder()

    public init() {}

    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
        try base.recordGenericSubstitution(type)
    }

    public mutating func recordArgument<Value>(
        _ argument: RemoteCallArgument<Value>
    ) throws where Value: Codable & Sendable {
        try base.recordArgument(argument)
    }

    public mutating func recordReturnType<R>(_ type: R.Type) throws where R: Codable & Sendable {
        try base.recordReturnType(type)
    }

    public mutating func recordErrorType<E>(_ type: E.Type) throws where E: Error {
        try base.recordErrorType(type)
    }

    public mutating func doneRecording() throws {
        try base.doneRecording()
    }

    mutating func recordTarget(_ target: RemoteCallTarget) {
        base.recordTarget(target)
    }

    mutating func makeInvocationEnvelope(
        recipientID: String,
        senderID: String? = nil
    ) throws -> InvocationEnvelope {
        try base.makeInvocationEnvelope(recipientID: recipientID, senderID: senderID)
    }
}
#endif
