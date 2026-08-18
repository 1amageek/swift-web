public struct ActorFieldID: Hashable, Sendable {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public enum ActorWireType: UInt8, Hashable, Sendable {
    case null = 0
    case boolean = 1
    case signedInteger = 2
    case unsignedInteger = 3
    case float32 = 4
    case float64 = 5
    case string = 6
    case bytes = 7
    case message = 8
    case enumeration = 9
    case sequence = 10
    case map = 11
}

public protocol ActorPayloadEncodable: Sendable {
    func encode(to encoder: inout ActorPayloadEncoder) throws
}

public protocol ActorPayloadDecodable: Sendable {
    init(from decoder: inout ActorPayloadDecoder) throws
}

public typealias ActorPayloadCodable = ActorPayloadEncodable & ActorPayloadDecodable

public struct ActorGeneratedCodec<Value: Sendable>: Sendable {
    private let encodeValue: @Sendable (Value) throws -> ActorByteBuffer
    private let decodeValue: @Sendable (
        ActorByteBuffer,
        ActorPortableDecodingOptions
    ) throws -> Value

    public init(
        encode: @escaping @Sendable (Value) throws -> ActorByteBuffer,
        decode: @escaping @Sendable (ActorByteBuffer) throws -> Value
    ) {
        self.encodeValue = encode
        self.decodeValue = { payload, _ in
            try decode(payload)
        }
    }

    public init(
        encode: @escaping @Sendable (Value) throws -> ActorByteBuffer,
        decodeWithOptions: @escaping @Sendable (
            ActorByteBuffer,
            ActorPortableDecodingOptions
        ) throws -> Value
    ) {
        self.encodeValue = encode
        self.decodeValue = decodeWithOptions
    }

    public func encode(_ value: Value) throws -> ActorByteBuffer {
        try encodeValue(value)
    }

    public func decode(
        _ payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) throws -> Value {
        try decodeValue(payload, options)
    }
}

public struct ActorPayloadEncoder: Sendable {
    private var storage: [UInt8] = []

    public init() {}

    public mutating func appendNull(field: ActorFieldID) throws {
        try append(field: field, wireType: .null, payload: ActorByteBuffer())
    }

    public mutating func append(_ value: Bool, field: ActorFieldID) throws {
        try append(
            field: field,
            wireType: .boolean,
            payload: ActorByteBuffer([value ? 1 : 0])
        )
    }

    public mutating func append<T: FixedWidthInteger & SignedInteger>(
        _ value: T,
        field: ActorFieldID
    ) throws {
        guard let checked = Int64(exactly: value) else {
            throw ActorSystemError.encodingFailed
        }
        try appendFixedWidth(
            UInt64(bitPattern: checked),
            field: field,
            wireType: .signedInteger
        )
    }

    public mutating func append<T: FixedWidthInteger & UnsignedInteger>(
        _ value: T,
        field: ActorFieldID
    ) throws {
        guard let checked = UInt64(exactly: value) else {
            throw ActorSystemError.encodingFailed
        }
        try appendFixedWidth(checked, field: field, wireType: .unsignedInteger)
    }

    public mutating func append(_ value: Float, field: ActorFieldID) throws {
        try appendFixedWidth(value.bitPattern, field: field, wireType: .float32)
    }

    public mutating func append(_ value: Double, field: ActorFieldID) throws {
        try appendFixedWidth(value.bitPattern, field: field, wireType: .float64)
    }

    public mutating func append(_ value: String, field: ActorFieldID) throws {
        try append(
            field: field,
            wireType: .string,
            payload: ActorByteBuffer(Array(value.utf8))
        )
    }

    public mutating func append(
        bytes: ActorByteBuffer,
        field: ActorFieldID
    ) throws {
        try append(field: field, wireType: .bytes, payload: bytes)
    }

    public mutating func append(
        message: ActorByteBuffer,
        field: ActorFieldID
    ) throws {
        try append(field: field, wireType: .message, payload: message)
    }

    public mutating func append(
        sequence: ActorByteBuffer,
        field: ActorFieldID
    ) throws {
        try append(field: field, wireType: .sequence, payload: sequence)
    }

    public mutating func append(
        map: ActorByteBuffer,
        field: ActorFieldID
    ) throws {
        try append(field: field, wireType: .map, payload: map)
    }

    public mutating func appendEnumeration(
        caseID: UInt32,
        associatedValues: ActorByteBuffer,
        field: ActorFieldID
    ) throws {
        var payload: [UInt8] = []
        payload.reserveCapacity(4 + associatedValues.count)
        appendBigEndian(caseID, to: &payload)
        associatedValues.withUnsafeBytes { bytes in
            payload.append(contentsOf: bytes)
        }
        try append(
            field: field,
            wireType: .enumeration,
            payload: ActorByteBuffer(payload)
        )
    }

    public func finish() -> ActorByteBuffer {
        ActorByteBuffer(storage)
    }

    mutating func appendRaw(
        field: ActorFieldID,
        wireType: ActorWireType,
        payload: ActorByteBuffer
    ) throws {
        try append(field: field, wireType: wireType, payload: payload)
    }

    private mutating func append<T: FixedWidthInteger>(
        _ value: T,
        field: ActorFieldID,
        wireType: ActorWireType
    ) throws {
        var payload: [UInt8] = []
        payload.reserveCapacity(MemoryLayout<T>.size)
        var shift = (MemoryLayout<T>.size - 1) * 8
        while shift >= 0 {
            payload.append(UInt8(truncatingIfNeeded: value >> T(shift)))
            if shift == 0 {
                break
            }
            shift -= 8
        }
        try append(
            field: field,
            wireType: wireType,
            payload: ActorByteBuffer(payload)
        )
    }

    private mutating func appendFixedWidth<T: FixedWidthInteger>(
        _ value: T,
        field: ActorFieldID,
        wireType: ActorWireType
    ) throws {
        try append(value, field: field, wireType: wireType)
    }

    private mutating func append(
        field: ActorFieldID,
        wireType: ActorWireType,
        payload: ActorByteBuffer
    ) throws {
        guard let payloadCount = UInt32(exactly: payload.count) else {
            throw ActorSystemError.encodingFailed
        }
        appendBigEndian(field.rawValue, to: &storage)
        storage.append(wireType.rawValue)
        appendBigEndian(payloadCount, to: &storage)
        payload.withUnsafeBytes { bytes in
            storage.append(contentsOf: bytes)
        }
    }
}

public struct ActorPayloadDecoder: Sendable {
    private let buffer: ActorByteBuffer
    private let maximumCollectionElements: Int
    private let maximumNestingDepth: Int
    private let depth: Int
    private var index = 0
    private var decodedFieldIDs: Set<ActorFieldID> = []

    public init(
        _ buffer: ActorByteBuffer,
        maximumCollectionElements: Int,
        maximumNestingDepth: Int,
        depth: Int = 0
    ) throws {
        guard maximumCollectionElements >= 0,
              maximumNestingDepth > 0,
              depth < maximumNestingDepth
        else {
            throw ActorSystemError.decodingFailed
        }
        self.buffer = buffer
        self.maximumCollectionElements = maximumCollectionElements
        self.maximumNestingDepth = maximumNestingDepth
        self.depth = depth
    }

    public init(
        _ buffer: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws {
        try self.init(
            buffer,
            maximumCollectionElements: options.maximumCollectionElements,
            maximumNestingDepth: options.maximumNestingDepth,
            depth: options.currentNestingDepth
        )
    }

    public var hasRemainingFields: Bool {
        index < buffer.count
    }

    public mutating func nextField() throws -> ActorFieldView? {
        guard hasRemainingFields else {
            return nil
        }
        guard decodedFieldIDs.count < maximumCollectionElements,
              buffer.count - index >= 9
        else {
            throw ActorSystemError.decodingFailed
        }

        let fieldID = ActorFieldID(try readUInt32())
        guard let wireType = ActorWireType(rawValue: buffer[index]) else {
            throw ActorSystemError.decodingFailed
        }
        index += 1
        let rawLength = try readUInt32()
        guard let length = Int(exactly: rawLength) else {
            throw ActorSystemError.decodingFailed
        }
        guard length >= 0, length <= buffer.count - index else {
            throw ActorSystemError.decodingFailed
        }
        guard decodedFieldIDs.insert(fieldID).inserted else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("A portable payload contains a duplicate field")
            )
        }
        let range = index..<(index + length)
        index += length
        return ActorFieldView(
            id: fieldID,
            wireType: wireType,
            owner: buffer,
            range: range,
            maximumCollectionElements: maximumCollectionElements,
            maximumNestingDepth: maximumNestingDepth,
            depth: depth
        )
    }

    private mutating func readUInt32() throws -> UInt32 {
        guard buffer.count - index >= 4 else {
            throw ActorSystemError.decodingFailed
        }
        var value: UInt32 = 0
        for _ in 0..<4 {
            value = (value << 8) | UInt32(buffer[index])
            index += 1
        }
        return value
    }
}

public struct ActorFieldView: Sendable {
    public let id: ActorFieldID
    public let wireType: ActorWireType
    private let owner: ActorByteBuffer
    private let range: Range<Int>
    private let maximumCollectionElements: Int
    private let maximumNestingDepth: Int
    private let depth: Int

    fileprivate init(
        id: ActorFieldID,
        wireType: ActorWireType,
        owner: ActorByteBuffer,
        range: Range<Int>,
        maximumCollectionElements: Int,
        maximumNestingDepth: Int,
        depth: Int
    ) {
        self.id = id
        self.wireType = wireType
        self.owner = owner
        self.range = range
        self.maximumCollectionElements = maximumCollectionElements
        self.maximumNestingDepth = maximumNestingDepth
        self.depth = depth
    }

    public var isNull: Bool {
        wireType == .null && range.isEmpty
    }

    public func decodeBool() throws -> Bool {
        try require(.boolean, byteCount: 1)
        switch owner[range.lowerBound] {
        case 0: return false
        case 1: return true
        default: throw ActorSystemError.decodingFailed
        }
    }

    public func decodeSignedInteger<T: FixedWidthInteger & SignedInteger>(
        as type: T.Type
    ) throws -> T {
        try require(.signedInteger, byteCount: 8)
        let raw = try readUInt64()
        guard let value = T(exactly: Int64(bitPattern: raw)) else {
            throw ActorSystemError.decodingFailed
        }
        return value
    }

    public func decodeUnsignedInteger<T: FixedWidthInteger & UnsignedInteger>(
        as type: T.Type
    ) throws -> T {
        try require(.unsignedInteger, byteCount: 8)
        guard let value = T(exactly: try readUInt64()) else {
            throw ActorSystemError.decodingFailed
        }
        return value
    }

    public func decodeFloat() throws -> Float {
        try require(.float32, byteCount: 4)
        return Float(bitPattern: try readUInt32())
    }

    public func decodeDouble() throws -> Double {
        try require(.float64, byteCount: 8)
        return Double(bitPattern: try readUInt64())
    }

    public func decodeString() throws -> String {
        try require(.string)
        let bytes = copiedBytes()
        guard ActorUTF8.isValid(bytes) else {
            throw ActorSystemError.decodingFailed
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    public func decodeBytes() throws -> ActorByteBuffer {
        try require(.bytes)
        return owner.slice(range)
    }

    public func nestedDecoder(
        accepting wireTypes: Set<ActorWireType> = [.message, .sequence, .map]
    ) throws -> ActorPayloadDecoder {
        guard wireTypes.contains(wireType) else {
            throw ActorSystemError.decodingFailed
        }
        return try ActorPayloadDecoder(
            owner.slice(range),
            maximumCollectionElements: maximumCollectionElements,
            maximumNestingDepth: maximumNestingDepth,
            depth: depth + 1
        )
    }

    public func decodeEnumeration() throws -> (
        caseID: UInt32,
        associatedValues: ActorPayloadDecoder
    ) {
        try require(.enumeration)
        guard range.count >= 4 else {
            throw ActorSystemError.decodingFailed
        }
        let caseID = try readUInt32()
        let decoder = try ActorPayloadDecoder(
            owner.slice((range.lowerBound + 4)..<range.upperBound),
            maximumCollectionElements: maximumCollectionElements,
            maximumNestingDepth: maximumNestingDepth,
            depth: depth + 1
        )
        return (caseID, decoder)
    }

    public func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try owner.withUnsafeBytes { buffer in
            let rebased = UnsafeRawBufferPointer(rebasing: buffer[range])
            return try body(rebased)
        }
    }

    public func payloadBuffer() -> ActorByteBuffer {
        owner.slice(range)
    }

    private func require(
        _ expectedWireType: ActorWireType,
        byteCount: Int? = nil
    ) throws {
        guard wireType == expectedWireType,
              byteCount.map({ range.count == $0 }) ?? true
        else {
            throw ActorSystemError.decodingFailed
        }
    }

    private func copiedBytes() -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(range.count)
        for index in range {
            bytes.append(owner[index])
        }
        return bytes
    }

    private func readUInt32() throws -> UInt32 {
        guard range.count >= 4 else {
            throw ActorSystemError.decodingFailed
        }
        var value: UInt32 = 0
        for index in range.lowerBound..<(range.lowerBound + 4) {
            value = (value << 8) | UInt32(owner[index])
        }
        return value
    }

    private func readUInt64() throws -> UInt64 {
        guard range.count == 8 else {
            throw ActorSystemError.decodingFailed
        }
        var value: UInt64 = 0
        for index in range {
            value = (value << 8) | UInt64(owner[index])
        }
        return value
    }
}

private func appendBigEndian<T: FixedWidthInteger>(_ value: T, to bytes: inout [UInt8]) {
    var shift = (MemoryLayout<T>.size - 1) * 8
    while shift >= 0 {
        bytes.append(UInt8(truncatingIfNeeded: value >> T(shift)))
        if shift == 0 {
            break
        }
        shift -= 8
    }
}
