/// A host-neutral WebSocket the SwiftWeb core reads from and writes to.
/// Host adapters bridge it to their native socket (Vapor WebSocketKit,
/// browser WebSocket, Durable Object hibernatable WebSocket).
public protocol WebSocketChannel: Sendable {
    func send(_ text: String) async throws
    func onText(_ handler: @Sendable @escaping (String) async throws -> Void)
    func close() async throws
}
