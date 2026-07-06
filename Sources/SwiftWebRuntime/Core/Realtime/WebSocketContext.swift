import SwiftWebHostKit

public struct WebSocketContext: Sendable {
    public let request: Request
    private let channel: any WebSocketChannel

    init(request: Request, channel: any WebSocketChannel) {
        self.request = request
        self.channel = channel
    }

    public func send(_ text: String) async throws {
        try await channel.send(text)
    }

    public func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        let logger = request.logger
        channel.onText { text in
            do {
                try await handler(text)
            } catch {
                logger.error("WebSocket text handler failed: \(String(describing: error))")
            }
        }
    }
}
