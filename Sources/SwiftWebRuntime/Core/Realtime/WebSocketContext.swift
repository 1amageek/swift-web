import SwiftWebHost

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

    public func send(_ bytes: WebSocketBinaryBuffer) async throws {
        try await channel.send(bytes)
    }

    public func send(_ bytes: [UInt8]) async throws {
        try await channel.send(WebSocketBinaryBuffer(bytes))
    }

    public func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        let logger = request.logger
        channel.onText { text in
            do {
                try await handler(text)
            } catch {
                logger.error("WebSocket text handler failed: \(RuntimeErrorText.of(error))")
            }
        }
    }

    public func onBinary(
        _ handler: @Sendable @escaping (WebSocketBinaryBuffer) async throws -> Void
    ) {
        let logger = request.logger
        channel.onBinary { bytes in
            do {
                try await handler(bytes)
            } catch {
                logger.error("WebSocket binary handler failed: \(RuntimeErrorText.of(error))")
            }
        }
    }

    public func onBinaryBytes(
        _ handler: @Sendable @escaping ([UInt8]) async throws -> Void
    ) {
        onBinary { buffer in
            try await handler(buffer.copyBytes())
        }
    }

    public func onClose(_ handler: @Sendable @escaping () async -> Void) async {
        await channel.onClose(handler)
    }

    public func close() async throws {
        try await channel.close()
    }
}
