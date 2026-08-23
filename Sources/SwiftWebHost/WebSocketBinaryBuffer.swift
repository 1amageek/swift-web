private final class WebSocketArrayBinaryStorage: WebSocketBinaryStorage, Sendable {
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

/// An immutable owner and range for one binary WebSocket message.
///
/// Slices retain the original storage. Use `withUnsafeBytes` to borrow the
/// contiguous readable range without allocating, and `copyBytes()` only at an
/// API boundary that requires an array.
public struct WebSocketBinaryBuffer: Sendable, RandomAccessCollection {
    public typealias Element = UInt8
    public typealias Index = Int
    public typealias SubSequence = WebSocketBinaryBuffer

    private let storage: any WebSocketBinaryStorage
    private let range: Range<Int>

    public init(_ bytes: [UInt8] = []) {
        self.storage = WebSocketArrayBinaryStorage(bytes)
        self.range = bytes.indices
    }

    @_spi(Hosting)
    public init<Storage: WebSocketBinaryStorage>(storage: Storage) {
        self.storage = storage
        self.range = 0..<storage.count
    }

    private init(
        storage: any WebSocketBinaryStorage,
        range: Range<Int>
    ) {
        self.storage = storage
        self.range = range
    }

    public var startIndex: Int {
        0
    }

    public var endIndex: Int {
        count
    }

    public var count: Int {
        range.count
    }

    public var isEmpty: Bool {
        range.isEmpty
    }

    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "WebSocket byte index is out of bounds")
        return storage[range.lowerBound + index]
    }

    public subscript(bounds: Range<Int>) -> WebSocketBinaryBuffer {
        precondition(
            bounds.lowerBound >= 0 && bounds.upperBound <= count,
            "WebSocket byte slice is out of bounds"
        )
        return WebSocketBinaryBuffer(
            storage: storage,
            range: (range.lowerBound + bounds.lowerBound)..<(range.lowerBound + bounds.upperBound)
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
            preconditionFailure("WebSocket binary storage did not provide its bytes")
        }
        return output
    }

    public func copyBytes() -> [UInt8] {
        withUnsafeBytes { Array($0) }
    }

    @_spi(Hosting)
    public func retainedStorage<Storage: WebSocketBinaryStorage>(
        as type: Storage.Type
    ) -> (storage: Storage, range: Range<Int>)? {
        guard let storage = storage as? Storage else {
            return nil
        }
        return (storage, range)
    }
}
