import HTTPTypes
import Logging
import NIOCore
import NIOHTTP1
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOPosix
import NIOWebSocket
import Synchronization
import TLSNIO
@_spi(Hosting) import SwiftWebCore

/// The native HTTP/1.1 host pipeline. HTTP and RFC 6455 upgrade negotiation
/// share the same listener and lower into the same host-neutral route table.
struct SwiftWebNIOHTTPServer: Sendable {
    private typealias HTTPChannel = NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>
    private typealias WebSocketAsyncChannel = NIOAsyncChannel<WebSocketFrame, WebSocketFrame>

    private enum UpgradeResult: Sendable {
        case http(HTTPChannel, remoteAddress: String?)
        case webSocket(
            WebSocketAsyncChannel,
            request: HTTPRequest,
            remoteAddress: String?
        )
    }

    private static let maximumWebSocketMessageBytes = 16 * 1024 * 1024
    private static let maximumWebSocketFragments = 1_024

    let hostname: String
    let port: Int
    let transport: HTTPServerTransportConfiguration
    let handler: SwiftWebHostHTTPHandler
    let logger: Logger

    func serve() async throws {
        let serverChannel: NIOAsyncChannel<EventLoopFuture<UpgradeResult>, Never> =
            try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
                .bind(host: hostname, port: port) { channel in
                    self.configure(channel)
                }

        try await withThrowingDiscardingTaskGroup { group in
            try await serverChannel.executeThenClose { inbound in
                for try await upgradeFuture in inbound {
                    group.addTask {
                        await self.handle(upgradeFuture)
                    }
                }
            }
        }
    }

    private func configure(_ channel: Channel) -> EventLoopFuture<EventLoopFuture<UpgradeResult>> {
        channel.eventLoop.makeCompletedFuture {
            let remoteAddress = channel.remoteAddress.map(String.init(describing:))
            if let tlsHandler = try transport.makeTLSHandler() {
                try channel.pipeline.syncOperations.addHandlers(
                    tlsHandler,
                    SwiftWebTLSConnectionErrorHandler(logger: logger)
                )
            }
            let upgrader = NIOTypedWebSocketServerUpgrader<UpgradeResult>(
                maxFrameSize: Self.maximumWebSocketMessageBytes,
                shouldUpgrade: { channel, requestHead in
                    let promise = channel.eventLoop.makePromise(of: HTTPHeaders?.self)
                    promise.completeWithTask {
                        let request = try HTTPRequest(
                            requestHead,
                            secure: self.transport.isSecure,
                            splitCookie: false
                        )
                        guard let fields = try await self.handler.webSocketUpgradeHeaders(
                            for: request,
                            remoteAddress: remoteAddress
                        ) else {
                            return nil
                        }
                        return HTTPHeaders(fields)
                    }
                    return promise.futureResult
                },
                upgradePipelineHandler: { channel, requestHead in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(
                            NIOWebSocketFrameAggregator(
                                minNonFinalFragmentSize: 1,
                                maxAccumulatedFrameCount: Self.maximumWebSocketFragments,
                                maxAccumulatedFrameSize: Self.maximumWebSocketMessageBytes
                            )
                        )
                        let asyncChannel = try WebSocketAsyncChannel(
                            wrappingChannelSynchronously: channel
                        )
                        let request = try HTTPRequest(
                            requestHead,
                            secure: self.transport.isSecure,
                            splitCookie: false
                        )
                        return .webSocket(
                            asyncChannel,
                            request: request,
                            remoteAddress: remoteAddress
                        )
                    }
                }
            )
            let upgradeConfiguration = NIOTypedHTTPServerUpgradeConfiguration(
                upgraders: [upgrader],
                notUpgradingCompletionHandler: { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(
                            HTTP1ToHTTPServerCodec(secure: self.transport.isSecure)
                        )
                        let asyncChannel = try HTTPChannel(
                            wrappingChannelSynchronously: channel
                        )
                        return .http(asyncChannel, remoteAddress: remoteAddress)
                    }
                }
            )
            return try channel.pipeline.syncOperations.configureUpgradableHTTPServerPipeline(
                configuration: .init(upgradeConfiguration: upgradeConfiguration)
            )
        }
    }

    private func handle(_ future: EventLoopFuture<UpgradeResult>) async {
        do {
            switch try await future.get() {
            case .http(let channel, let remoteAddress):
                try await handleHTTP(channel, remoteAddress: remoteAddress)
            case .webSocket(let channel, let request, let remoteAddress):
                try await handleWebSocket(
                    channel,
                    request: request,
                    remoteAddress: remoteAddress
                )
            }
        } catch {
            guard !Self.isExpectedConnectionTermination(error) else {
                return
            }
            logger.error("SwiftWeb connection failed: \(String(describing: error))")
        }
    }

    private static func isExpectedConnectionTermination(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        guard let channelError = error as? ChannelError else {
            return false
        }

        switch channelError {
        case .inappropriateOperationForState,
             .ioOnClosedChannel,
             .alreadyClosed,
             .inputClosed,
             .outputClosed,
             .eof:
            return true
        default:
            return false
        }
    }

    private func handleHTTP(
        _ channel: HTTPChannel,
        remoteAddress: String?
    ) async throws {
        try await channel.executeThenClose { inbound, outbound in
            var request: HTTPRequest?
            var body = ByteBuffer()
            var bodyLimit = SwiftWebHostHTTPHandler.defaultMaxBodySize
            var exceededBodyLimit = false

            for try await part in inbound {
                switch part {
                case .head(let nextRequest):
                    guard request == nil else {
                        throw SwiftWebNIOHTTPServerError.invalidHTTPMessageSequence
                    }
                    request = nextRequest
                    body.clear()
                    let match = handler.httpMatch(for: nextRequest)
                    bodyLimit = handler.bodyLimit(for: match)
                    exceededBodyLimit = false
                case .body(var bytes):
                    guard request != nil else {
                        throw SwiftWebNIOHTTPServerError.invalidHTTPMessageSequence
                    }
                    guard !exceededBodyLimit else {
                        continue
                    }
                    if bytes.readableBytes > bodyLimit - min(body.readableBytes, bodyLimit) {
                        exceededBodyLimit = true
                        body.clear()
                        continue
                    }
                    body.writeBuffer(&bytes)
                case .end:
                    guard let completedRequest = request else {
                        throw SwiftWebNIOHTTPServerError.invalidHTTPMessageSequence
                    }
                    if exceededBodyLimit {
                        let response = HTTPServerErrorResponder.errorResponse(
                            status: .contentTooLarge,
                            reason: "Request body exceeds the route's collection limit"
                        )
                        try await Self.send(
                            response,
                            for: completedRequest,
                            through: outbound
                        )
                    } else {
                        let bodyBytes = body.readableBytes == 0
                            ? nil
                            : body.getBytes(
                                at: body.readerIndex,
                                length: body.readableBytes
                            )
                        let match = handler.httpMatch(for: completedRequest)
                        let response = await handler.response(
                            for: completedRequest,
                            match: match,
                            bodyBytes: bodyBytes,
                            remoteAddress: remoteAddress
                        )
                        try await Self.send(
                            response,
                            for: completedRequest,
                            through: outbound
                        )
                    }
                    request = nil
                    body.clear()
                    exceededBodyLimit = false
                }
            }
            guard request == nil else {
                throw SwiftWebNIOHTTPServerError.invalidHTTPMessageSequence
            }
        }
    }

    private func handleWebSocket(
        _ channel: WebSocketAsyncChannel,
        request: HTTPRequest,
        remoteAddress: String?
    ) async throws {
        try await channel.executeThenClose { inbound, outbound in
            let socket = NIOWebSocketChannel(outbound: outbound)
            await handler.connectWebSocket(
                for: request,
                remoteAddress: remoteAddress,
                channel: socket
            )
            try await socket.receive(from: inbound)
        }
    }

    private static func send(
        _ response: Response,
        for request: HTTPRequest,
        through outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>
    ) async throws {
        var headers = response.headers
        let statusCode = response.status.code
        let statusForbidsBody = (100..<200).contains(statusCode)
            || statusCode == 204
            || statusCode == 304
        let isHead = request.method == .head

        if statusForbidsBody {
            headers[.contentLength] = nil
            headers[.transferEncoding] = nil
            try await outbound.write(.head(HTTPResponse(
                status: response.status,
                headerFields: headers
            )))
            try await outbound.write(.end(nil))
            return
        }

        if let produce = response.body.stream {
            headers[.contentLength] = nil
            headers[.transferEncoding] = isHead ? nil : "chunked"
            try await outbound.write(.head(HTTPResponse(
                status: response.status,
                headerFields: headers
            )))
            guard !isHead else {
                try await outbound.write(.end(nil))
                return
            }

            let (chunks, continuation) = AsyncThrowingStream<[UInt8], any Error>.makeStream(
                bufferingPolicy: .bufferingOldest(16)
            )
            async let producing: Void = {
                do {
                    try await produce(NIOHTTPBodyWriter(continuation: continuation))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                    throw error
                }
            }()
            for try await chunk in chunks {
                var buffer = ByteBuffer()
                buffer.writeBytes(chunk)
                try await outbound.write(.body(buffer))
            }
            try await producing
            try await outbound.write(.end(nil))
            return
        }

        let bytes = response.body.bytes ?? []
        headers[.contentLength] = String(bytes.count)
        headers[.transferEncoding] = nil
        try await outbound.write(.head(HTTPResponse(
            status: response.status,
            headerFields: headers
        )))
        if !isHead, !bytes.isEmpty {
            var buffer = ByteBuffer()
            buffer.writeBytes(bytes)
            try await outbound.write(.body(buffer))
        }
        try await outbound.write(.end(nil))
    }
}

private enum SwiftWebNIOHTTPServerError: Error, Sendable {
    case invalidHTTPMessageSequence
    case invalidWebSocketMessage
    case responseBodyBackpressureExceeded
    case responseBodyTerminated
}

private struct NIOHTTPBodyWriter: BodyWriter {
    let continuation: AsyncThrowingStream<[UInt8], any Error>.Continuation

    func write(_ bytes: [UInt8]) async throws {
        switch continuation.yield(bytes) {
        case .enqueued:
            return
        case .dropped:
            throw SwiftWebNIOHTTPServerError.responseBodyBackpressureExceeded
        case .terminated:
            throw SwiftWebNIOHTTPServerError.responseBodyTerminated
        @unknown default:
            throw SwiftWebNIOHTTPServerError.responseBodyTerminated
        }
    }
}

private final class NIOWebSocketChannel: WebSocketChannel, Sendable {
    private struct State: Sendable {
        var textHandler: (@Sendable (String) async throws -> Void)?
        var binaryHandler: (@Sendable ([UInt8]) async throws -> Void)?
        var closeHandler: (@Sendable () async -> Void)?
        var isClosed = false
        var deliveredClose = false
    }

    private let outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>
    private let state = Mutex(State())

    init(outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>) {
        self.outbound = outbound
    }

    func send(_ text: String) async throws {
        try requireOpen()
        var buffer = ByteBuffer()
        buffer.writeString(text)
        try await outbound.write(
            WebSocketFrame(fin: true, opcode: .text, data: buffer)
        )
    }

    func send(_ bytes: [UInt8]) async throws {
        try requireOpen()
        var buffer = ByteBuffer()
        buffer.writeBytes(bytes)
        try await outbound.write(
            WebSocketFrame(fin: true, opcode: .binary, data: buffer)
        )
    }

    func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        state.withLock { state in
            guard !state.isClosed else {
                return
            }
            state.textHandler = handler
        }
    }

    func onBinary(_ handler: @Sendable @escaping ([UInt8]) async throws -> Void) {
        state.withLock { state in
            guard !state.isClosed else {
                return
            }
            state.binaryHandler = handler
        }
    }

    func onClose(_ handler: @Sendable @escaping () async -> Void) async {
        let deliverNow = state.withLock { state -> Bool in
            guard !state.isClosed else {
                guard !state.deliveredClose else {
                    return false
                }
                state.deliveredClose = true
                return true
            }
            guard !state.deliveredClose else {
                return false
            }
            state.closeHandler = handler
            return false
        }
        if deliverNow {
            await handler()
        }
    }

    func close() async throws {
        let shouldSend = state.withLock { state -> Bool in
            guard !state.isClosed else {
                return false
            }
            state.isClosed = true
            return true
        }
        guard shouldSend else {
            return
        }
        do {
            try await outbound.write(
                WebSocketFrame(
                    fin: true,
                    opcode: .connectionClose,
                    data: ByteBuffer()
                )
            )
            outbound.finish()
            await deliverCloseIfNeeded()
        } catch {
            outbound.finish()
            await deliverCloseIfNeeded()
            throw error
        }
    }

    func receive(
        from inbound: NIOAsyncChannelInboundStream<WebSocketFrame>
    ) async throws {
        do {
            for try await frame in inbound {
                switch frame.opcode {
                case .text:
                    let bytes = Self.bytes(in: frame)
                    guard let text = String(validating: bytes, as: UTF8.self),
                          let handler = state.withLock({ $0.textHandler })
                    else {
                        throw SwiftWebNIOHTTPServerError.invalidWebSocketMessage
                    }
                    try await handler(text)
                case .binary:
                    guard let handler = state.withLock({ $0.binaryHandler }) else {
                        throw SwiftWebNIOHTTPServerError.invalidWebSocketMessage
                    }
                    try await handler(Self.bytes(in: frame))
                case .ping:
                    try requireOpen()
                    try await outbound.write(
                        WebSocketFrame(
                            fin: true,
                            opcode: .pong,
                            data: frame.unmaskedData
                        )
                    )
                case .pong:
                    continue
                case .connectionClose:
                    try await replyToClose(frame)
                    await markClosedAndDeliver()
                    return
                case .continuation:
                    throw SwiftWebNIOHTTPServerError.invalidWebSocketMessage
                default:
                    throw SwiftWebNIOHTTPServerError.invalidWebSocketMessage
                }
            }
            await markClosedAndDeliver()
        } catch {
            await markClosedAndDeliver()
            throw error
        }
    }

    private func replyToClose(_ frame: WebSocketFrame) async throws {
        let shouldReply = state.withLock { state -> Bool in
            guard !state.isClosed else {
                return false
            }
            state.isClosed = true
            return true
        }
        guard shouldReply else {
            return
        }
        var data = frame.unmaskedData
        let closeCode = data.readSlice(length: min(2, data.readableBytes)) ?? ByteBuffer()
        try await outbound.write(
            WebSocketFrame(
                fin: true,
                opcode: .connectionClose,
                data: closeCode
            )
        )
        outbound.finish()
    }

    private func requireOpen() throws {
        try state.withLock { state in
            guard !state.isClosed else {
                throw SwiftWebNIOHTTPServerError.invalidWebSocketMessage
            }
        }
    }

    private func markClosedAndDeliver() async {
        state.withLock { $0.isClosed = true }
        outbound.finish()
        await deliverCloseIfNeeded()
    }

    private func deliverCloseIfNeeded() async {
        let handler = state.withLock { state -> (@Sendable () async -> Void)? in
            guard state.isClosed else {
                return nil
            }
            let handler = state.deliveredClose ? nil : state.closeHandler
            if handler != nil {
                state.deliveredClose = true
            }
            state.textHandler = nil
            state.binaryHandler = nil
            state.closeHandler = nil
            return handler
        }
        if let handler {
            await handler()
        }
    }

    private static func bytes(in frame: WebSocketFrame) -> [UInt8] {
        let data = frame.unmaskedData
        return data.getBytes(at: data.readerIndex, length: data.readableBytes) ?? []
    }
}
