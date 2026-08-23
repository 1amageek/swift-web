import NIOCore
@_spi(Hosting) import SwiftWebHost

final class NIOWebSocketBinaryStorage: WebSocketBinaryStorage, Sendable {
    // ByteBuffer is the immutable COW owner for this adapter view. The
    // borrowed readable pointer never escapes `withUnsafeReadableBytes`.
    let buffer: ByteBuffer

    init(_ buffer: ByteBuffer) {
        self.buffer = buffer
    }

    var count: Int {
        buffer.readableBytes
    }

    subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "NIO WebSocket byte index is out of bounds")
        guard let byte = buffer.getInteger(
            at: buffer.readerIndex + index,
            as: UInt8.self
        ) else {
            preconditionFailure("NIO WebSocket storage violated its readable range")
        }
        return byte
    }

    func withUnsafeBytes(
        _ body: (UnsafeRawBufferPointer) throws -> Void
    ) rethrows {
        try buffer.withUnsafeReadableBytes(body)
    }

    static func byteBuffer(for bytes: WebSocketBinaryBuffer) -> ByteBuffer {
        if let retained = bytes.retainedStorage(as: NIOWebSocketBinaryStorage.self) {
            let sourceIndex = retained.storage.buffer.readerIndex + retained.range.lowerBound
            guard let slice = retained.storage.buffer.getSlice(
                at: sourceIndex,
                length: retained.range.count
            ) else {
                preconditionFailure("NIO WebSocket storage violated its retained range")
            }
            return slice
        }

        // A foreign owner cannot be adopted by ByteBuffer. Borrow its bytes
        // once and copy directly into the final outbound NIO owner.
        var buffer = ByteBufferAllocator().buffer(capacity: bytes.count)
        bytes.withUnsafeBytes { source in
            buffer.writeBytes(source)
        }
        return buffer
    }
}
