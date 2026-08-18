private final class ActorByteStorage: Sendable {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }
}

public struct ActorByteBuffer: Hashable, Sendable {
    private let storage: ActorByteStorage
    private let range: Range<Int>

    public init() {
        self.storage = ActorByteStorage([])
        self.range = 0..<0
    }

    public init(_ bytes: [UInt8]) {
        self.storage = ActorByteStorage(bytes)
        self.range = bytes.indices
    }

    private init(storage: ActorByteStorage, range: Range<Int>) {
        self.storage = storage
        self.range = range
    }

    public var count: Int {
        range.count
    }

    public var isEmpty: Bool {
        range.isEmpty
    }

    public var bytes: [UInt8] {
        Array(storage.bytes[range])
    }

    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "Actor byte index is out of bounds")
        return storage.bytes[range.lowerBound + index]
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
        try storage.bytes.withUnsafeBytes { buffer in
            try body(UnsafeRawBufferPointer(rebasing: buffer[range]))
        }
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
