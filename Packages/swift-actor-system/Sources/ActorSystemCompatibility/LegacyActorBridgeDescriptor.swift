@preconcurrency import ActorRuntime
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LegacyActorMethodBridge: Sendable {
    public let legacyTargetIdentifier: String
    public let methodID: ActorMethodID
    private let decodeArgumentsValue: @Sendable ([Data]) throws -> ActorByteBuffer
    private let encodeResultValue: @Sendable (ActorByteBuffer) throws -> Data?

    public init(
        legacyTargetIdentifier: String,
        methodID: ActorMethodID,
        decodeArguments: @escaping @Sendable ([Data]) throws -> ActorByteBuffer,
        encodeResult: @escaping @Sendable (ActorByteBuffer) throws -> Data?
    ) {
        self.legacyTargetIdentifier = legacyTargetIdentifier
        self.methodID = methodID
        self.decodeArgumentsValue = decodeArguments
        self.encodeResultValue = encodeResult
    }

    func decodeArguments(_ arguments: [Data]) throws -> ActorByteBuffer {
        try decodeArgumentsValue(arguments)
    }

    func encodeResult(_ payload: ActorByteBuffer) throws -> Data? {
        try encodeResultValue(payload)
    }
}

public struct LegacyActorBridgeDescriptor: Sendable {
    public let legacyContract: String
    public let actorTypeID: ActorTypeID
    public let schemaFingerprint: ActorSchemaFingerprint
    private let methods: [String: LegacyActorMethodBridge]

    public init(
        legacyContract: String,
        actorTypeID: ActorTypeID,
        schemaFingerprint: ActorSchemaFingerprint,
        methods: [LegacyActorMethodBridge]
    ) throws {
        guard !legacyContract.isEmpty, !legacyContract.contains(":") else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("A legacy contract must be a nonempty colon-free prefix")
            )
        }
        var indexed: [String: LegacyActorMethodBridge] = [:]
        for method in methods {
            guard indexed[method.legacyTargetIdentifier] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("A legacy target identifier is registered more than once")
                )
            }
            indexed[method.legacyTargetIdentifier] = method
        }
        self.legacyContract = legacyContract
        self.actorTypeID = actorTypeID
        self.schemaFingerprint = schemaFingerprint
        self.methods = indexed
    }

    func method(target: String) -> LegacyActorMethodBridge? {
        methods[target]
    }

    func address(recipientID: String) -> ActorAddress? {
        let prefix = legacyContract + ":"
        guard recipientID.hasPrefix(prefix) else {
            return nil
        }
        return ActorAddress(
            type: actorTypeID,
            identity: String(recipientID.dropFirst(prefix.count))
        )
    }
}
