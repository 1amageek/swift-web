/// Immutable contiguous storage used by host adapters to retain native byte
/// owners across asynchronous WebSocket callbacks.
///
/// A conformer owns initialized byte-addressable memory for its entire
/// lifetime. `count` is the exact readable byte count. `withUnsafeBytes` calls
/// its body exactly once before returning. The borrowed pointer is valid only
/// for that synchronous call and must not escape; mutation and rebinding are
/// not permitted.
@_spi(Hosting)
public protocol WebSocketBinaryStorage: Sendable {
    var count: Int { get }

    subscript(index: Int) -> UInt8 { get }

    func withUnsafeBytes(
        _ body: (UnsafeRawBufferPointer) throws -> Void
    ) rethrows
}
