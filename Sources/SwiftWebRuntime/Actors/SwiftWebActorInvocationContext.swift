import ActorSystemCore

public struct SwiftWebActorInvocationContext: Sendable, Equatable {
    public let principalID: String?
    public let sessionID: String?
    public let tenantID: String?
    public let remoteAddress: String?
    public let peerID: String?

    public init(
        principalID: String? = nil,
        sessionID: String? = nil,
        tenantID: String? = nil,
        remoteAddress: String? = nil,
        peerID: String? = nil
    ) {
        self.principalID = principalID
        self.sessionID = sessionID
        self.tenantID = tenantID
        self.remoteAddress = remoteAddress
        self.peerID = peerID
    }
}

public struct SwiftWebActorInvocationContextCodec: Sendable {
    private enum Field {
        static let principalID = ActorFieldID(1)
        static let sessionID = ActorFieldID(2)
        static let tenantID = ActorFieldID(3)
        static let remoteAddress = ActorFieldID(4)
        static let peerID = ActorFieldID(5)
    }

    public let maximumEncodedBytes: Int
    public let maximumFieldBytes: Int

    public init(
        maximumEncodedBytes: Int = 4_096,
        maximumFieldBytes: Int = 1_024
    ) {
        self.maximumEncodedBytes = maximumEncodedBytes
        self.maximumFieldBytes = maximumFieldBytes
    }

    public func encode(
        _ context: SwiftWebActorInvocationContext
    ) throws -> ActorByteBuffer {
        guard maximumEncodedBytes >= 0, maximumFieldBytes >= 0 else {
            throw ActorSystemError.encodingFailed
        }
        var encoder = ActorPayloadEncoder()
        try append(context.principalID, field: Field.principalID, to: &encoder)
        try append(context.sessionID, field: Field.sessionID, to: &encoder)
        try append(context.tenantID, field: Field.tenantID, to: &encoder)
        try append(context.remoteAddress, field: Field.remoteAddress, to: &encoder)
        try append(context.peerID, field: Field.peerID, to: &encoder)
        let payload = encoder.finish()
        guard payload.count <= maximumEncodedBytes else {
            throw ActorSystemError.encodingFailed
        }
        return payload
    }

    public func decode(
        _ payload: ActorByteBuffer
    ) throws -> SwiftWebActorInvocationContext {
        guard maximumEncodedBytes >= 0,
              maximumFieldBytes >= 0,
              payload.count <= maximumEncodedBytes
        else {
            throw ActorSystemError.decodingFailed
        }
        var decoder = try ActorPayloadDecoder(
            payload,
            maximumCollectionElements: 5,
            maximumNestingDepth: 1
        )
        var principalID: String?
        var sessionID: String?
        var tenantID: String?
        var remoteAddress: String?
        var peerID: String?

        while let field = try decoder.nextField() {
            switch field.id {
            case Field.principalID:
                principalID = try decodeString(field)
            case Field.sessionID:
                sessionID = try decodeString(field)
            case Field.tenantID:
                tenantID = try decodeString(field)
            case Field.remoteAddress:
                remoteAddress = try decodeString(field)
            case Field.peerID:
                peerID = try decodeString(field)
            default:
                continue
            }
        }
        return SwiftWebActorInvocationContext(
            principalID: principalID,
            sessionID: sessionID,
            tenantID: tenantID,
            remoteAddress: remoteAddress,
            peerID: peerID
        )
    }

    private func append(
        _ value: String?,
        field: ActorFieldID,
        to encoder: inout ActorPayloadEncoder
    ) throws {
        guard let value else {
            return
        }
        guard value.utf8.count <= maximumFieldBytes else {
            throw ActorSystemError.encodingFailed
        }
        try encoder.append(value, field: field)
    }

    private func decodeString(_ field: ActorFieldView) throws -> String {
        let value = try field.decodeString()
        guard value.utf8.count <= maximumFieldBytes else {
            throw ActorSystemError.decodingFailed
        }
        return value
    }
}
