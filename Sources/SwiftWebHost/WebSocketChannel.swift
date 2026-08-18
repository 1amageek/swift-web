/// A host-neutral WebSocket the SwiftWeb core reads from and writes to.
/// Host adapters bridge it to their native socket.
public protocol WebSocketChannel: Sendable {
    func send(_ text: String) async throws
    func send(_ bytes: [UInt8]) async throws
    func onText(_ handler: @Sendable @escaping (String) async throws -> Void)
    func onBinary(_ handler: @Sendable @escaping ([UInt8]) async throws -> Void)
    func onClose(_ handler: @Sendable @escaping () async -> Void) async
    func close() async throws
}
