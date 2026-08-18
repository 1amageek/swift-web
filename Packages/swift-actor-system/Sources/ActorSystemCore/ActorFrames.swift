public struct ActorInvocationFrame: Hashable, Sendable {
    public let callID: ActorCallID
    public let invocation: ActorInvocation
    public let remainingTimeoutNanoseconds: UInt64?

    public init(
        callID: ActorCallID,
        invocation: ActorInvocation,
        remainingTimeoutNanoseconds: UInt64?
    ) {
        self.callID = callID
        self.invocation = invocation
        self.remainingTimeoutNanoseconds = remainingTimeoutNanoseconds
    }
}

public struct ActorSystemFailure: Hashable, Sendable {
    public let code: ActorSystemErrorCode
    public let metadata: ActorByteBuffer

    public init(code: ActorSystemErrorCode, metadata: ActorByteBuffer = ActorByteBuffer()) {
        self.code = code
        self.metadata = metadata
    }

    public init(error: ActorSystemError) {
        self.code = error.code
        var bytes: [UInt8] = []
        switch error {
        case .unsupportedWireVersion(let version):
            Self.append(version, to: &bytes)
        case .schemaMismatch(let mismatch):
            Self.append(mismatch.expected.high, to: &bytes)
            Self.append(mismatch.expected.low, to: &bytes)
            Self.append(mismatch.received.high, to: &bytes)
            Self.append(mismatch.received.low, to: &bytes)
        case .remoteFailure(let failure):
            Self.append(failure.code, to: &bytes)
        default:
            break
        }
        self.metadata = ActorByteBuffer(bytes)
    }

    func decodedUnsupportedWireVersion() -> UInt16? {
        guard code == .unsupportedWireVersion else {
            return nil
        }
        return readInteger(at: 0, as: UInt16.self)
    }

    func decodedSchemaMismatch() -> ActorSchemaMismatch? {
        guard code == .schemaMismatch,
              let expectedHigh = readInteger(at: 0, as: UInt64.self),
              let expectedLow = readInteger(at: 8, as: UInt64.self),
              let receivedHigh = readInteger(at: 16, as: UInt64.self),
              let receivedLow = readInteger(at: 24, as: UInt64.self)
        else {
            return nil
        }
        return ActorSchemaMismatch(
            expected: ActorSchemaFingerprint(high: expectedHigh, low: expectedLow),
            received: ActorSchemaFingerprint(high: receivedHigh, low: receivedLow)
        )
    }

    func decodedRemoteFailureCode() -> UInt32? {
        guard code == .remoteFailure else {
            return nil
        }
        return readInteger(at: 0, as: UInt32.self)
    }

    private func readInteger<T: FixedWidthInteger>(
        at offset: Int,
        as type: T.Type
    ) -> T? {
        guard offset >= 0, metadata.count - offset >= MemoryLayout<T>.size else {
            return nil
        }
        var value: T = 0
        for index in offset..<(offset + MemoryLayout<T>.size) {
            value = (value << 8) | T(metadata[index])
        }
        return value
    }

    private static func append<T: FixedWidthInteger>(
        _ value: T,
        to bytes: inout [UInt8]
    ) {
        var shift = (MemoryLayout<T>.size - 1) * 8
        while shift >= 0 {
            bytes.append(UInt8(truncatingIfNeeded: value >> T(shift)))
            if shift == 0 {
                break
            }
            shift -= 8
        }
    }
}

public enum ActorInvocationOutcome: Hashable, Sendable {
    case success(ActorInvocationResult)
    case systemFailure(ActorSystemFailure)
    case applicationFailure(ActorApplicationFailure)
}

public struct ActorResultFrame: Hashable, Sendable {
    public let callID: ActorCallID
    public let outcome: ActorInvocationOutcome

    public init(callID: ActorCallID, outcome: ActorInvocationOutcome) {
        self.callID = callID
        self.outcome = outcome
    }
}

public struct ActorHelloFrame: Hashable, Sendable {
    public let session: ActorSessionID
    public let maximumWireVersion: UInt16

    public init(session: ActorSessionID, maximumWireVersion: UInt16) {
        self.session = session
        self.maximumWireVersion = maximumWireVersion
    }
}

public enum ActorFrame: Hashable, Sendable {
    case invocation(ActorInvocationFrame)
    case result(ActorResultFrame)
    case cancellation(ActorCallID)
    case hello(ActorHelloFrame)
}

public struct ActorInboundFrame: Hashable, Sendable {
    public let frame: ActorFrame
    public let transport: ActorTransportID
    public let replyEndpoint: ActorEndpoint
    public let metadata: ActorByteBuffer

    public init(
        frame: ActorFrame,
        transport: ActorTransportID,
        replyEndpoint: ActorEndpoint,
        metadata: ActorByteBuffer = ActorByteBuffer()
    ) {
        self.frame = frame
        self.transport = transport
        self.replyEndpoint = replyEndpoint
        self.metadata = metadata
    }
}
