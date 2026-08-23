#if os(WASI)
import ActorSystemCore
import JavaScriptKit
import SwiftWebActors

/// A bounded binary actor channel backed by the browser WebSocket API.
/// JavaScript ownership stays on `MainActor`; actor transport state stays in
/// this actor and is identical for standard and Embedded WASM profiles.
public actor BrowserSwiftWebActorBinaryChannel: SwiftWebActorBinaryChannel {
    private enum Phase: Sendable, Equatable {
        case initialized
        case starting
        case running
        case stopped
    }

    public nonisolated let endpoint: ActorEndpoint
    public nonisolated let incoming: AsyncThrowingStream<ActorByteBuffer, any Error>

    private nonisolated let incomingContinuation:
        AsyncThrowingStream<ActorByteBuffer, any Error>.Continuation
    private let url: String
    private let maximumFrameBytes: Int
    private var phase = Phase.initialized
    private var driver: BrowserSwiftWebSocketDriver?
    private var startContinuation: CheckedContinuation<Void, any Error>?

    public init(
        url: String = "/_swiftweb/actors/socket",
        endpoint: ActorEndpoint = .swiftWebWebSocket,
        configuration: ActorSystemConfiguration
    ) throws {
        guard configuration.maximumFrameBytes >= ActorFrameCodec.minimumFrameBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame limit is invalid")
            )
        }
        guard configuration.maximumConcurrentInboundCalls > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket buffer limit is invalid")
            )
        }
        let pair = AsyncThrowingStream<ActorByteBuffer, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(
                configuration.maximumConcurrentInboundCalls
            )
        )
        self.url = url
        self.endpoint = endpoint
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
        self.maximumFrameBytes = configuration.maximumFrameBytes
    }

    public func start() async throws {
        guard phase == .initialized else {
            throw ActorSystemError.alreadyStarted
        }
        phase = .starting
        let driver = await BrowserSwiftWebSocketDriver(
            maximumFrameBytes: maximumFrameBytes,
            onOpen: { [self] in
                Task { await didOpen() }
            },
            onBinary: { [incomingContinuation] bytes -> ActorSystemError? in
                switch incomingContinuation.yield(ActorByteBuffer(bytes)) {
                case .enqueued:
                    return nil
                case .dropped:
                    return ActorSystemError.overloaded
                case .terminated:
                    return ActorSystemError.transportClosed
                @unknown default:
                    return ActorSystemError.transportClosed
                }
            },
            onClose: { [self] error in
                Task { await didClose(error: error) }
            }
        )
        self.driver = driver
        do {
            try await driver.connect(url: url)
            if phase == .running {
                return
            }
            guard phase == .starting else {
                throw ActorSystemError.transportClosed
            }
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    switch phase {
                    case .starting:
                        startContinuation = continuation
                    case .running:
                        continuation.resume()
                    case .initialized, .stopped:
                        continuation.resume(
                            throwing: ActorSystemError.transportClosed
                        )
                    }
                }
            } onCancel: {
                Task { await self.cancelStart() }
            }
        } catch {
            await stop(throwing: error)
            throw error
        }
    }

    public func send(_ bytes: ActorByteBuffer) async throws {
        guard phase == .running, let driver else {
            throw ActorSystemError.transportClosed
        }
        guard bytes.count <= maximumFrameBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame exceeds its limit")
            )
        }
        // JavaScript takes ownership of a typed array at this boundary.
        try await driver.send(bytes.copyBytes())
    }

    public func shutdown() async {
        await stop(throwing: nil)
    }

    private func didOpen() {
        guard phase == .starting else {
            return
        }
        phase = .running
        startContinuation?.resume()
        startContinuation = nil
    }

    private func didClose(error: ActorSystemError?) async {
        await stop(throwing: error)
    }

    private func cancelStart() async {
        guard phase == .starting else {
            return
        }
        await stop(throwing: ActorSystemError.cancelled)
    }

    private func stop(throwing error: (any Error)?) async {
        guard phase != .stopped || driver != nil else {
            return
        }
        phase = .stopped
        if let error {
            startContinuation?.resume(throwing: error)
            incomingContinuation.finish(throwing: error)
        } else {
            startContinuation?.resume(throwing: ActorSystemError.transportClosed)
            incomingContinuation.finish()
        }
        startContinuation = nil
        let driver = self.driver
        self.driver = nil
        await driver?.shutdown()
    }
}

@MainActor
private final class BrowserSwiftWebSocketDriver {
    private struct Callbacks: Sendable {
        let onOpen: @Sendable () -> Void
        let onBinary: @Sendable ([UInt8]) -> ActorSystemError?
        let onClose: @Sendable (ActorSystemError?) -> Void
    }

    private let maximumFrameBytes: Int
    private var callbacks: Callbacks?
    private var socket: JSObject?
    private var retainedClosures: [JSClosure] = []
    private var signalledClose = false

    init(
        maximumFrameBytes: Int,
        onOpen: @escaping @Sendable () -> Void,
        onBinary: @escaping @Sendable ([UInt8]) -> ActorSystemError?,
        onClose: @escaping @Sendable (ActorSystemError?) -> Void
    ) {
        self.maximumFrameBytes = maximumFrameBytes
        self.callbacks = Callbacks(
            onOpen: onOpen,
            onBinary: onBinary,
            onClose: onClose
        )
    }

    func connect(url: String) throws {
        guard let socketConstructor = JSObject.global.WebSocket.function else {
            throw ActorSystemError.transportUnavailable(.swiftWebWebSocket)
        }
        let socket = socketConstructor.new(url)
        socket.binaryType = .string(JSString("arraybuffer"))

        let onOpen = JSClosure { [self] _ in
            callbacks?.onOpen()
            return .undefined
        }
        let onMessage = JSClosure { [self] arguments in
            receiveMessage(arguments)
            return .undefined
        }
        let onClose = JSClosure { [self] _ in
            signalClose(error: nil)
            return .undefined
        }
        let onError = JSClosure { [self] _ in
            signalClose(error: .transportClosed)
            return .undefined
        }
        self.socket = socket
        retainedClosures = [onOpen, onMessage, onClose, onError]
        socket.onopen = .object(onOpen)
        socket.onmessage = .object(onMessage)
        socket.onclose = .object(onClose)
        socket.onerror = .object(onError)
    }

    func send(_ bytes: [UInt8]) throws {
        guard let socket,
              socket.readyState.number == 1,
              bytes.count <= maximumFrameBytes
        else {
            throw ActorSystemError.transportClosed
        }
        _ = socket.send?(JSUint8Array(bytes).jsValue)
    }

    func shutdown() {
        let socket = self.socket
        detach()
        if let socket, socket.readyState.number != 3 {
            _ = socket.close?()
        }
    }

    private func receiveMessage(_ arguments: [JSValue]) {
        guard let buffer = arguments.first?.object?.data.object,
              let uint8ArrayConstructor = JSObject.global.Uint8Array.function
        else {
            signalClose(error: .decodingFailed)
            return
        }
        let typedArray = JSUint8Array(
            unsafelyWrapping: uint8ArrayConstructor.new(buffer)
        )
        guard typedArray.length <= maximumFrameBytes else {
            signalClose(error: .invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame exceeds its limit")
            ))
            return
        }
        let bytes = typedArray.withUnsafeBytes { Array($0) }
        if let error = callbacks?.onBinary(bytes) {
            signalClose(error: error)
        }
    }

    private func signalClose(error: ActorSystemError?) {
        guard !signalledClose else {
            return
        }
        signalledClose = true
        let callback = callbacks?.onClose
        shutdown()
        callback?(error)
    }

    private func detach() {
        if let socket {
            socket.onopen = .undefined
            socket.onmessage = .undefined
            socket.onclose = .undefined
            socket.onerror = .undefined
        }
        socket = nil
        retainedClosures.removeAll(keepingCapacity: false)
        callbacks = nil
    }
}
#endif
