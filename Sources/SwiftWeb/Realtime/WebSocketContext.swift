import WebSocketKit

public struct WebSocketContext: Sendable {
    public let request: Request
    private let socket: WebSocket

    init(request: Request, socket: WebSocket) {
        self.request = request
        self.socket = socket
    }

    public func send(_ text: String) async throws {
        try await socket.send(text)
    }

    public func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        socket.onText { _, text async in
            do {
                try await handler(text)
            } catch {
                request.logger.error("WebSocket text handler failed: \(String(describing: error))")
            }
        }
    }
}
