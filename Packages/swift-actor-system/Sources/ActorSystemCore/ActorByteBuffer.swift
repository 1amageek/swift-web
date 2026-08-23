private final class ActorArrayByteStorage: ActorByteBufferStorage, Sendable {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var count: Int {
        bytes.count
    }

    subscript(index: Int) -> UInt8 {
        bytes[index]
    }

    func withUnsafeBytes(
        _ body: (UnsafeRawBufferPointer) throws -> Void
    ) rethrows {
        try bytes.withUnsafeBytes(body)
    }
}

public struct ActorByteBuffer: Hashable, Sendable {
    private let storage: any ActorByteBufferStorage
    private let range: Range<Int>

    public init() {
        self.storage = ActorArrayByteStorage([])
        self.range = 0..<0
    }

    public init(_ bytes: [UInt8]) {
        self.storage = ActorArrayByteStorage(bytes)
        self.range = bytes.indices
    }

    @_spi(Transport)
    public init<Storage: ActorByteBufferStorage>(storage: Storage) {
        self.storage = storage
        self.range = 0..<storage.count
    }

    private init(
        storage: any ActorByteBufferStorage,
        range: Range<Int>
    ) {
        self.storage = storage
        self.range = range
    }

    public var count: Int {
        range.count
    }

    public var isEmpty: Bool {
        range.isEmpty
    }

    /// Materializes the readable range as an array.
    public var bytes: [UInt8] {
        copyBytes()
    }

    public func copyBytes() -> [UInt8] {
        withUnsafeBytes { Array($0) }
    }

    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "Actor byte index is out of bounds")
        return storage[range.lowerBound + index]
    }

    public func slice(_ subrange: Range<Int>) -> ActorByteBuffer {
        precondition(
            subrange.lowerBound >= 0 && subrange.upperBound <= count,
            "Actor byte slice is out of bounds"
        )
        return ActorByteBuffer(
            storage: storage,
            range: (range.lowerBound + subrange.lowerBound)..<(range.lowerBound + subrange.upperBound)
        )
    }

    public func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        var output: Result?
        try storage.withUnsafeBytes { buffer in
            output = try body(UnsafeRawBufferPointer(rebasing: buffer[range]))
        }
        guard let output else {
            preconditionFailure("Actor byte storage did not provide its bytes")
        }
        return output
    }

    @_spi(Transport)
    public func retainedStorage<Storage: ActorByteBufferStorage>(
        as type: Storage.Type
    ) -> (storage: Storage, range: Range<Int>)? {
        guard let storage = storage as? Storage else {
            return nil
        }
        return (storage, range)
    }

    public static func == (lhs: ActorByteBuffer, rhs: ActorByteBuffer) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        for index in 0..<lhs.count where lhs[index] != rhs[index] {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for index in 0..<count {
            hasher.combine(self[index])
        }
    }

}

#if !hasFeature(Embedded)
extension ActorByteBuffer: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode([UInt8].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(copyBytes())
    }
}
#endif
