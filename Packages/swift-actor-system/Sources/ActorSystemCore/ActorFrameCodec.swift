public struct ActorFrameCodec: Sendable {
    public static let wireVersion: UInt16 = 1
    public static let minimumFrameBytes = 30

    private enum FrameKind: UInt8 {
        case invocation = 1
        case result = 2
        case cancellation = 3
        case hello = 4
    }

    private enum OutcomeKind: UInt8 {
        case success = 0
        case systemFailure = 1
        case applicationFailure = 2
    }

    private let maximumFrameBytes: Int
    private let maximumPayloadBytes: Int
    private let maximumIdentityBytes: Int

    public init(
        maximumFrameBytes: Int,
        maximumPayloadBytes: Int,
        maximumIdentityBytes: Int
    ) {
        self.maximumFrameBytes = maximumFrameBytes
        self.maximumPayloadBytes = maximumPayloadBytes
        self.maximumIdentityBytes = maximumIdentityBytes
    }

    public init(configuration: ActorSystemConfiguration) {
        self.init(
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumPayloadBytes: configuration.maximumPayloadBytes,
            maximumIdentityBytes: configuration.maximumIdentityBytes
        )
    }

    public func encode(_ frame: ActorFrame) throws -> ActorByteBuffer {
        var header = ByteWriter()
        let kind: FrameKind
        let callID: ActorCallID
        let payload: ActorByteBuffer

        switch frame {
        case .invocation(let invocation):
            kind = .invocation
            callID = invocation.callID
            let identity = Array(invocation.invocation.recipient.identity.utf8)
            guard identity.count <= maximumIdentityBytes,
                  let identityCount = UInt16(exactly: identity.count)
            else {
                throw ActorSystemError.encodingFailed
            }
            header.append(invocation.invocation.recipient.type.high)
            header.append(invocation.invocation.recipient.type.low)
            header.append(identityCount)
            header.append(contentsOf: identity)
            header.append(invocation.invocation.method.rawValue)
            header.append(invocation.invocation.schemaFingerprint.high)
            header.append(invocation.invocation.schemaFingerprint.low)
            if let timeout = invocation.remainingTimeoutNanoseconds {
                header.append(UInt8(1))
                header.append(timeout)
            } else {
                header.append(UInt8(0))
            }
            payload = invocation.invocation.payload
        case .result(let result):
            kind = .result
            callID = result.callID
            switch result.outcome {
            case .success(let invocationResult):
                header.append(OutcomeKind.success.rawValue)
                payload = invocationResult.payload
            case .systemFailure(let failure):
                header.append(OutcomeKind.systemFailure.rawValue)
                header.append(failure.code.rawValue)
                payload = failure.metadata
            case .applicationFailure(let failure):
                header.append(OutcomeKind.applicationFailure.rawValue)
                header.append(failure.typeID.high)
                header.append(failure.typeID.low)
                payload = failure.payload
            }
        case .cancellation(let cancelledCallID):
            kind = .cancellation
            callID = cancelledCallID
            payload = ActorByteBuffer()
        case .hello(let hello):
            kind = .hello
            callID = ActorCallID(session: hello.session, sequence: 0)
            header.append(hello.maximumWireVersion)
            payload = ActorByteBuffer()
        }

        guard callID.session.rawValue != 0 else {
            throw ActorSystemError.encodingFailed
        }
        switch kind {
        case .hello:
            guard callID.sequence == 0 else {
                throw ActorSystemError.encodingFailed
            }
        case .invocation, .result, .cancellation:
            guard callID.sequence != 0 else {
                throw ActorSystemError.encodingFailed
            }
        }

        guard let headerCount = UInt16(exactly: header.count),
              payload.count <= maximumPayloadBytes,
              let payloadCount = UInt32(exactly: payload.count)
        else {
            throw ActorSystemError.encodingFailed
        }

        guard maximumFrameBytes >= Self.minimumFrameBytes,
              header.count <= maximumFrameBytes - Self.minimumFrameBytes
        else {
            throw ActorSystemError.encodingFailed
        }
        let headerEnd = Self.minimumFrameBytes + header.count
        guard payload.count <= maximumFrameBytes - headerEnd else {
            throw ActorSystemError.encodingFailed
        }
        let totalSize = headerEnd + payload.count

        var output = ByteWriter(reservingCapacity: totalSize)
        output.append(contentsOf: [0x53, 0x41, 0x43, 0x54])
        output.append(Self.wireVersion)
        output.append(kind.rawValue)
        output.append(UInt8(0))
        output.append(headerCount)
        output.append(payloadCount)
        output.append(callID.session.rawValue)
        output.append(callID.sequence)
        output.append(contentsOf: header.bytes)
        output.append(contentsOf: payload)
        return ActorByteBuffer(output.bytes)
    }

    public func decode(_ buffer: ActorByteBuffer) throws -> ActorFrame {
        guard buffer.count >= Self.minimumFrameBytes,
              buffer.count <= maximumFrameBytes
        else {
            throw invalid("Frame length is outside the configured range")
        }

        var reader = ByteReader(buffer)
        guard try reader.readByte() == 0x53,
              try reader.readByte() == 0x41,
              try reader.readByte() == 0x43,
              try reader.readByte() == 0x54
        else {
            throw invalid("Frame magic is invalid")
        }
        let version = try reader.readUInt16()
        guard version == Self.wireVersion else {
            throw ActorSystemError.unsupportedWireVersion(version)
        }
        guard let kind = FrameKind(rawValue: try reader.readByte()) else {
            throw invalid("Frame kind is unknown")
        }
        let flags = try reader.readByte()
        guard flags == 0 else {
            throw invalid("Frame flags are not supported")
        }
        let headerLength = Int(try reader.readUInt16())
        let rawPayloadLength = try reader.readUInt32()
        guard let payloadLength = Int(exactly: rawPayloadLength) else {
            throw invalid("Payload length cannot be represented on this target")
        }
        guard payloadLength <= maximumPayloadBytes else {
            throw invalid("Payload length exceeds the configured limit")
        }
        let callID = ActorCallID(
            session: ActorSessionID(try reader.readUInt64()),
            sequence: try reader.readUInt64()
        )
        guard callID.session.rawValue != 0 else {
            throw invalid("Frame session identity must not be zero")
        }
        switch kind {
        case .hello:
            guard callID.sequence == 0 else {
                throw invalid("Hello frame call sequence must be zero")
            }
        case .invocation, .result, .cancellation:
            guard callID.sequence != 0 else {
                throw invalid("Actor call sequence must not be zero")
            }
        }
        guard headerLength <= reader.remaining,
              payloadLength <= reader.remaining - headerLength,
              reader.remaining == headerLength + payloadLength
        else {
            throw invalid("Frame lengths do not match the owned buffer")
        }

        let headerBuffer = try reader.readBuffer(count: headerLength)
        let payload = try reader.readBuffer(count: payloadLength)
        var header = ByteReader(headerBuffer)

        switch kind {
        case .invocation:
            let typeID = ActorTypeID(
                high: try header.readUInt64(),
                low: try header.readUInt64()
            )
            let identityLength = Int(try header.readUInt16())
            guard identityLength <= maximumIdentityBytes else {
                throw invalid("Actor identity exceeds the configured limit")
            }
            let identityBytes = try header.readBytes(count: identityLength)
            guard ActorUTF8.isValid(identityBytes) else {
                throw invalid("Actor identity is not valid UTF-8")
            }
            let identity = String(decoding: identityBytes, as: UTF8.self)
            let method = ActorMethodID(try header.readUInt64())
            let fingerprint = ActorSchemaFingerprint(
                high: try header.readUInt64(),
                low: try header.readUInt64()
            )
            let hasTimeout = try header.readByte()
            let timeout: UInt64?
            switch hasTimeout {
            case 0:
                timeout = nil
            case 1:
                timeout = try header.readUInt64()
            default:
                throw invalid("Invocation timeout presence flag is invalid")
            }
            try requireExhausted(header)
            return .invocation(
                ActorInvocationFrame(
                    callID: callID,
                    invocation: ActorInvocation(
                        recipient: ActorAddress(type: typeID, identity: identity),
                        method: method,
                        schemaFingerprint: fingerprint,
                        payload: payload
                    ),
                    remainingTimeoutNanoseconds: timeout
                )
            )
        case .result:
            guard let outcomeKind = OutcomeKind(rawValue: try header.readByte()) else {
                throw invalid("Result outcome kind is unknown")
            }
            let outcome: ActorInvocationOutcome
            switch outcomeKind {
            case .success:
                outcome = .success(ActorInvocationResult(payload: payload))
            case .systemFailure:
                let rawCode = try header.readUInt32()
                guard let code = ActorSystemErrorCode(rawValue: rawCode) else {
                    throw invalid("System failure code is unknown")
                }
                outcome = .systemFailure(
                    ActorSystemFailure(code: code, metadata: payload)
                )
            case .applicationFailure:
                let typeID = ActorTypeID(
                    high: try header.readUInt64(),
                    low: try header.readUInt64()
                )
                outcome = .applicationFailure(
                    ActorApplicationFailure(typeID: typeID, payload: payload)
                )
            }
            try requireExhausted(header)
            return .result(ActorResultFrame(callID: callID, outcome: outcome))
        case .cancellation:
            try requireExhausted(header)
            guard payload.isEmpty else {
                throw invalid("Cancellation frame payload must be empty")
            }
            return .cancellation(callID)
        case .hello:
            let maximumVersion = try header.readUInt16()
            try requireExhausted(header)
            guard payload.isEmpty, callID.sequence == 0 else {
                throw invalid("Hello frame contains invalid fields")
            }
            return .hello(
                ActorHelloFrame(
                    session: callID.session,
                    maximumWireVersion: maximumVersion
                )
            )
        }
    }

    private func requireExhausted(_ reader: ByteReader) throws {
        guard reader.remaining == 0 else {
            throw invalid("Frame header contains trailing bytes")
        }
    }

    private func invalid(_ reason: String) -> ActorSystemError {
        .invalidFrame(ActorProtocolViolation(reason))
    }
}

enum ActorUTF8 {
    static func isValid(_ bytes: [UInt8]) -> Bool {
        var index = 0
        while index < bytes.count {
            let first = bytes[index]
            if first <= 0x7F {
                index += 1
                continue
            }

            let requiredContinuationCount: Int
            let minimumSecond: UInt8
            let maximumSecond: UInt8
            switch first {
            case 0xC2...0xDF:
                requiredContinuationCount = 1
                minimumSecond = 0x80
                maximumSecond = 0xBF
            case 0xE0:
                requiredContinuationCount = 2
                minimumSecond = 0xA0
                maximumSecond = 0xBF
            case 0xE1...0xEC, 0xEE...0xEF:
                requiredContinuationCount = 2
                minimumSecond = 0x80
                maximumSecond = 0xBF
            case 0xED:
                requiredContinuationCount = 2
                minimumSecond = 0x80
                maximumSecond = 0x9F
            case 0xF0:
                requiredContinuationCount = 3
                minimumSecond = 0x90
                maximumSecond = 0xBF
            case 0xF1...0xF3:
                requiredContinuationCount = 3
                minimumSecond = 0x80
                maximumSecond = 0xBF
            case 0xF4:
                requiredContinuationCount = 3
                minimumSecond = 0x80
                maximumSecond = 0x8F
            default:
                return false
            }

            guard index + requiredContinuationCount < bytes.count else {
                return false
            }
            let second = bytes[index + 1]
            guard second >= minimumSecond, second <= maximumSecond else {
                return false
            }
            if requiredContinuationCount >= 2 {
                guard bytes[index + 2] >= 0x80, bytes[index + 2] <= 0xBF else {
                    return false
                }
            }
            if requiredContinuationCount == 3 {
                guard bytes[index + 3] >= 0x80, bytes[index + 3] <= 0xBF else {
                    return false
                }
            }
            index += requiredContinuationCount + 1
        }
        return true
    }
}

private struct ByteWriter {
    private(set) var bytes: [UInt8]

    init(reservingCapacity: Int = 0) {
        self.bytes = []
        self.bytes.reserveCapacity(reservingCapacity)
    }

    var count: Int {
        bytes.count
    }

    mutating func append(_ value: UInt8) {
        bytes.append(value)
    }

    mutating func append(_ value: UInt16) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }

    mutating func append(_ value: UInt32) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 24))
        bytes.append(UInt8(truncatingIfNeeded: value >> 16))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }

    mutating func append(_ value: UInt64) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 56))
        bytes.append(UInt8(truncatingIfNeeded: value >> 48))
        bytes.append(UInt8(truncatingIfNeeded: value >> 40))
        bytes.append(UInt8(truncatingIfNeeded: value >> 32))
        bytes.append(UInt8(truncatingIfNeeded: value >> 24))
        bytes.append(UInt8(truncatingIfNeeded: value >> 16))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }

    mutating func append(contentsOf values: [UInt8]) {
        bytes.append(contentsOf: values)
    }

    mutating func append(contentsOf buffer: ActorByteBuffer) {
        buffer.withUnsafeBytes { source in
            bytes.append(contentsOf: source)
        }
    }
}

private struct ByteReader {
    private let buffer: ActorByteBuffer
    private var index: Int = 0

    init(_ buffer: ActorByteBuffer) {
        self.buffer = buffer
    }

    var remaining: Int {
        buffer.count - index
    }

    mutating func readByte() throws -> UInt8 {
        guard remaining >= 1 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Frame is truncated")
            )
        }
        defer { index += 1 }
        return buffer[index]
    }

    mutating func readUInt16() throws -> UInt16 {
        let first = UInt16(try readByte())
        let second = UInt16(try readByte())
        return (first << 8) | second
    }

    mutating func readUInt32() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            value = (value << 8) | UInt32(try readByte())
        }
        return value
    }

    mutating func readUInt64() throws -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<8 {
            value = (value << 8) | UInt64(try readByte())
        }
        return value
    }

    mutating func readBytes(count: Int) throws -> [UInt8] {
        guard count >= 0, remaining >= count else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Frame field is truncated")
            )
        }
        let start = index
        index += count
        var bytes: [UInt8] = []
        bytes.reserveCapacity(count)
        for offset in start..<index {
            bytes.append(buffer[offset])
        }
        return bytes
    }

    mutating func readBuffer(count: Int) throws -> ActorByteBuffer {
        guard count >= 0, remaining >= count else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Frame field is truncated")
            )
        }
        let start = index
        index += count
        return buffer.slice(start..<index)
    }
}
