import Logging
import NIOCore

/// Observes transport-handshake failures before HTTP or WebSocket decoding
/// begins. Invalid TLS peers are connection-local and therefore logged at the
/// debug level rather than promoted to a server failure.
final class SwiftWebTLSConnectionErrorHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        logger.debug("SwiftWeb TLS connection failed: \(String(describing: error))")
        context.fireErrorCaught(error)
    }
}

@available(*, unavailable)
extension SwiftWebTLSConnectionErrorHandler: Sendable {}
