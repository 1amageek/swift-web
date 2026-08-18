public enum ActorSystemErrorCode: UInt32, Hashable, Sendable {
    case notStarted = 1
    case shuttingDown = 2
    case invalidFrame = 3
    case unsupportedWireVersion = 4
    case schemaMismatch = 5
    case actorNotFound = 6
    case targetUnavailable = 7
    case unauthorized = 8
    case activationFailed = 9
    case encodingFailed = 10
    case decodingFailed = 11
    case routeNotFound = 12
    case transportUnavailable = 13
    case transportClosed = 14
    case timeout = 15
    case cancelled = 16
    case overloaded = 17
    case remoteFailure = 18
    case sessionIdentityUnavailable = 19
    case callSequenceExhausted = 20
    case alreadyStarted = 21
}

public struct ActorProtocolViolation: Error, Hashable, Sendable {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }
}

public struct ActorSchemaMismatch: Error, Hashable, Sendable {
    public let expected: ActorSchemaFingerprint
    public let received: ActorSchemaFingerprint

    public init(expected: ActorSchemaFingerprint, received: ActorSchemaFingerprint) {
        self.expected = expected
        self.received = received
    }
}

public struct ActorRemoteFailure: Error, Hashable, Sendable {
    public let code: UInt32
    public let publicMessage: String?

    public init(code: UInt32, publicMessage: String? = nil) {
        self.code = code
        self.publicMessage = publicMessage
    }
}

public struct ActorApplicationFailure: Error, Hashable, Sendable {
    public let typeID: ActorTypeID
    public let payload: ActorByteBuffer

    public init(typeID: ActorTypeID, payload: ActorByteBuffer) {
        self.typeID = typeID
        self.payload = payload
    }
}

public enum ActorSystemError: Error, Hashable, Sendable {
    case notStarted
    case shuttingDown
    case invalidFrame(ActorProtocolViolation)
    case unsupportedWireVersion(UInt16)
    case schemaMismatch(ActorSchemaMismatch)
    case actorNotFound(ActorAddress)
    case targetUnavailable(ActorMethodID)
    case unauthorized
    case activationFailed
    case encodingFailed
    case decodingFailed
    case routeNotFound(ActorAddress)
    case transportUnavailable(ActorTransportID)
    case transportClosed
    case timeout
    case cancelled
    case overloaded
    case remoteFailure(ActorRemoteFailure)
    case sessionIdentityUnavailable
    case callSequenceExhausted
    case alreadyStarted

    public var code: ActorSystemErrorCode {
        switch self {
        case .notStarted: .notStarted
        case .shuttingDown: .shuttingDown
        case .invalidFrame: .invalidFrame
        case .unsupportedWireVersion: .unsupportedWireVersion
        case .schemaMismatch: .schemaMismatch
        case .actorNotFound: .actorNotFound
        case .targetUnavailable: .targetUnavailable
        case .unauthorized: .unauthorized
        case .activationFailed: .activationFailed
        case .encodingFailed: .encodingFailed
        case .decodingFailed: .decodingFailed
        case .routeNotFound: .routeNotFound
        case .transportUnavailable: .transportUnavailable
        case .transportClosed: .transportClosed
        case .timeout: .timeout
        case .cancelled: .cancelled
        case .overloaded: .overloaded
        case .remoteFailure: .remoteFailure
        case .sessionIdentityUnavailable: .sessionIdentityUnavailable
        case .callSequenceExhausted: .callSequenceExhausted
        case .alreadyStarted: .alreadyStarted
        }
    }
}
