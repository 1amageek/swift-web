#if SWIFTWEB_ACTORS
@_spi(Transport) import ActorSystemCore
@_spi(Hosting) import SwiftWebHost

struct SwiftWebActorBinaryStorage:
    ActorByteBufferStorage,
    WebSocketBinaryStorage,
    Sendable
{
    enum Source: Sendable {
        case actor(ActorByteBuffer)
        case webSocket(WebSocketBinaryBuffer)
    }

    let source: Source

    var count: Int {
        switch source {
        case .actor(let buffer):
            buffer.count
        case .webSocket(let buffer):
            buffer.count
        }
    }

    subscript(index: Int) -> UInt8 {
        switch source {
        case .actor(let buffer):
            buffer[index]
        case .webSocket(let buffer):
            buffer[index]
        }
    }

    func withUnsafeBytes(
        _ body: (UnsafeRawBufferPointer) throws -> Void
    ) rethrows {
        switch source {
        case .actor(let buffer):
            try buffer.withUnsafeBytes(body)
        case .webSocket(let buffer):
            try buffer.withUnsafeBytes(body)
        }
    }
}
#endif
