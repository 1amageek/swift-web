public struct ActorInvocation: Hashable, Sendable {
    public let recipient: ActorAddress
    public let method: ActorMethodID
    public let schemaFingerprint: ActorSchemaFingerprint
    public let payload: ActorByteBuffer

    public init(
        recipient: ActorAddress,
        method: ActorMethodID,
        schemaFingerprint: ActorSchemaFingerprint,
        payload: ActorByteBuffer
    ) {
        self.recipient = recipient
        self.method = method
        self.schemaFingerprint = schemaFingerprint
        self.payload = payload
    }
}

public struct ActorInvocationResult: Hashable, Sendable {
    public let payload: ActorByteBuffer

    public init(payload: ActorByteBuffer = ActorByteBuffer()) {
        self.payload = payload
    }
}

public struct ActorCallOptions: Hashable, Sendable {
    public let timeout: Duration?

    public init(timeout: Duration? = nil) {
        self.timeout = timeout
    }

    public static let defaults = ActorCallOptions()
}

public enum ActorInvocationOrigin: Hashable, Sendable {
    case local
    case remote(transport: ActorTransportID, endpoint: ActorEndpoint)
}

public struct ActorInvocationContext: Hashable, Sendable {
    public let callID: ActorCallID
    public let origin: ActorInvocationOrigin
    public let remainingTimeout: Duration?
    public let metadata: ActorByteBuffer

    public init(
        callID: ActorCallID,
        origin: ActorInvocationOrigin,
        remainingTimeout: Duration?,
        metadata: ActorByteBuffer = ActorByteBuffer()
    ) {
        self.callID = callID
        self.origin = origin
        self.remainingTimeout = remainingTimeout
        self.metadata = metadata
    }
}
