/// Immutable contiguous storage that can back an `ActorByteBuffer` without
/// materializing an intermediate byte array.
///
/// A conformer owns initialized byte-addressable memory for its entire
/// lifetime. `count` is the exact readable byte count. `withUnsafeBytes` calls
/// its body exactly once before returning. The borrowed pointer is valid only
/// for that synchronous call and must not escape; mutation and rebinding are
/// not permitted.
@_spi(Transport)
public protocol ActorByteBufferStorage: Sendable {
    var count: Int { get }

    subscript(index: Int) -> UInt8 { get }

    func withUnsafeBytes(
        _ body: (UnsafeRawBufferPointer) throws -> Void
    ) rethrows
}
