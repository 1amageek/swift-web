#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime
@preconcurrency import Distributed

public struct WebActorInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = Codable & Sendable

    private var base: CodableInvocationDecoder

    public init(envelope: InvocationEnvelope) throws {
        self.base = try CodableInvocationDecoder(envelope: envelope)
    }

    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
        try base.decodeGenericSubstitutions()
    }

    public mutating func decodeNextArgument<Argument>() throws -> Argument where Argument: Codable & Sendable {
        try base.decodeNextArgument()
    }

    public mutating func decodeReturnType() throws -> Any.Type? {
        try base.decodeReturnType()
    }

    public mutating func decodeErrorType() throws -> Any.Type? {
        try base.decodeErrorType()
    }
}
#endif
