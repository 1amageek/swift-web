#if os(WASI)
import ActorSystemCore
import JavaScriptKit
import SwiftWebActors
import Synchronization

public final class JavaScriptKitActorTransport: ActorTransport, Sendable {
    private enum Phase: Sendable, Equatable {
        case initialized
        case running
        case stopped
    }

    public let incoming: AsyncThrowingStream<ActorInboundFrame, any Error>
    private let incomingContinuation: AsyncThrowingStream<ActorInboundFrame, any Error>.Continuation
    private let frameCodec: ActorFrameCodec
    private let requestDriver: JavaScriptKitActorRequestDriver
    private let state = Mutex(Phase.initialized)

    @MainActor
    public init(configuration: ActorSystemConfiguration) {
        let pair = AsyncThrowingStream<ActorInboundFrame, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(
                max(1, configuration.maximumInFlightCalls)
            )
        )
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
        self.frameCodec = ActorFrameCodec(configuration: configuration)
        self.requestDriver = JavaScriptKitActorRequestDriver()
    }

    public func start() async throws {
        try state.withLock { phase in
            guard phase == .initialized else {
                throw ActorSystemError.alreadyStarted
            }
            phase = .running
        }
    }

    public func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint
    ) async throws {
        try requireRunning()
        guard case .result = frame else {
            let encoded = try frameCodec.encode(frame)
            let response = try await requestDriver.perform(
                endpoint: endpoint.transportSpecificAddress,
                body: encoded.bytes
            )
            guard response.isSuccessful else {
                throw actorSystemError(forHTTPStatus: response.status)
            }
            if response.status == 204 {
                return
            }
            guard let bytes = response.body else {
                throw ActorSystemError.decodingFailed
            }
            let responseFrame = try frameCodec.decode(ActorByteBuffer(bytes))
            guard case .result = responseFrame else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("HTTP actor response is not a result frame")
                )
            }
            let yieldResult = incomingContinuation.yield(
                ActorInboundFrame(
                    frame: responseFrame,
                    transport: .swiftWebHTTP,
                    replyEndpoint: endpoint
                )
            )
            switch yieldResult {
            case .enqueued:
                return
            case .dropped:
                throw ActorSystemError.overloaded
            case .terminated:
                throw ActorSystemError.transportClosed
            @unknown default:
                throw ActorSystemError.transportClosed
            }
        }
        throw ActorSystemError.invalidFrame(
            ActorProtocolViolation("HTTP client transport cannot send result frames")
        )
    }

    public func shutdown() async {
        let shouldFinish = state.withLock { phase -> Bool in
            guard phase != .stopped else {
                return false
            }
            phase = .stopped
            return true
        }
        if shouldFinish {
            await requestDriver.shutdown()
            incomingContinuation.finish()
        }
    }

    private func requireRunning() throws {
        try state.withLock { phase in
            guard phase == .running else {
                throw ActorSystemError.transportClosed
            }
        }
    }

    private func actorSystemError(forHTTPStatus status: Int) -> ActorSystemError {
        switch status {
        case 401, 403:
            .unauthorized
        case 408, 504:
            .timeout
        case 429, 503:
            .overloaded
        default:
            .remoteFailure(
                ActorRemoteFailure(code: UInt32(clamping: status))
            )
        }
    }
}

private struct JavaScriptKitActorHTTPResponse: Sendable {
    let status: Int
    let isSuccessful: Bool
    let body: [UInt8]?
}

@MainActor
private final class JavaScriptKitActorRequestDriver {
    private var isAccepting = true
    private var nextRequestID: UInt64 = 0
    private var abortControllers: [UInt64: JSObject] = [:]

    func perform(
        endpoint: String,
        body: [UInt8]
    ) async throws -> JavaScriptKitActorHTTPResponse {
        guard isAccepting else {
            throw ActorSystemError.transportClosed
        }
        guard !Task.isCancelled else {
            throw ActorSystemError.cancelled
        }
        guard nextRequestID < UInt64.max else {
            throw ActorSystemError.overloaded
        }
        guard let fetch = JSObject.global.fetch.function,
              let abortControllerConstructor = JSObject.global.AbortController.function,
              let objectConstructor = JSObject.global.Object.function
        else {
            throw ActorSystemError.transportUnavailable(.swiftWebHTTP)
        }

        nextRequestID += 1
        let requestID = nextRequestID
        let abortController = abortControllerConstructor.new()
        abortControllers[requestID] = abortController
        defer {
            abortControllers[requestID] = nil
        }

        do {
            return try await withTaskCancellationHandler {
                guard !Task.isCancelled else {
                    abort(requestID: requestID)
                    throw ActorSystemError.cancelled
                }
                let headers = objectConstructor.new()
                headers["Content-Type"] = "application/vnd.swift-actor-frame"
                headers["Accept"] = "application/vnd.swift-actor-frame"
                if let csrfHeader = csrfHeader() {
                    headers[csrfHeader.name] = .string(JSString(csrfHeader.value))
                }

                let options = objectConstructor.new()
                options["method"] = "POST"
                options["credentials"] = "same-origin"
                options["headers"] = .object(headers)
                options["body"] = JSUint8Array(body).jsValue
                options["signal"] = abortController.signal

                guard let responsePromise = JSPromise(from: fetch(endpoint, options)) else {
                    throw ActorSystemError.transportClosed
                }
                let response = try await responsePromise.swiftActorValue
                let status = Int(response.status.number ?? 0)
                let isSuccessful = response.ok.boolean == true
                if status == 204 || !isSuccessful {
                    return JavaScriptKitActorHTTPResponse(
                        status: status,
                        isSuccessful: isSuccessful,
                        body: nil
                    )
                }
                guard let arrayBufferPromise = JSPromise(from: response.arrayBuffer()) else {
                    throw ActorSystemError.transportClosed
                }
                let arrayBuffer = try await arrayBufferPromise.swiftActorValue
                guard let bufferObject = arrayBuffer.object,
                      let uint8ArrayConstructor = JSObject.global.Uint8Array.function
                else {
                    throw ActorSystemError.decodingFailed
                }
                let typedArray = JSUint8Array(
                    unsafelyWrapping: uint8ArrayConstructor.new(bufferObject)
                )
                return JavaScriptKitActorHTTPResponse(
                    status: status,
                    isSuccessful: true,
                    body: typedArray.withUnsafeBytes { Array($0) }
                )
            } onCancel: {
                Task { @MainActor in
                    self.abort(requestID: requestID)
                }
            }
        } catch {
            throw JavaScriptKitActorRequestErrorNormalizer.normalize(
                error,
                isCancelled: Task.isCancelled,
                isAccepting: isAccepting
            )
        }
    }

    func shutdown() {
        guard isAccepting else {
            return
        }
        isAccepting = false
        let controllers = Array(abortControllers.values)
        abortControllers.removeAll(keepingCapacity: false)
        for controller in controllers {
            _ = controller.abort?()
        }
    }

    private func abort(requestID: UInt64) {
        guard let controller = abortControllers.removeValue(forKey: requestID) else {
            return
        }
        _ = controller.abort?()
    }

    private func csrfHeader() -> (name: String, value: String)? {
        guard let runtime = JSObject.global.__swiftWebWasmRuntime.object else {
            return nil
        }
        let security = runtime.security
        guard let token = security.csrfToken.string else {
            return nil
        }
        return (
            security.csrfHeaderName.string ?? "X-CSRF-Token",
            token
        )
    }
}

public struct JavaScriptKitActorSessionIdentitySource: ActorSessionIdentitySource {
    public init() {}

    public func makeSessionID() async throws -> ActorSessionID {
        var value: UInt64 = 0
        while value == 0 {
            value = UInt64.random(in: 1...UInt64.max)
        }
        return ActorSessionID(value)
    }
}

private enum JavaScriptKitActorTransportError: Error, Sendable {
    case promiseRejected
}

@MainActor
private extension JSPromise {
    var swiftActorValue: JSValue {
        get async throws {
            let result: Swift.Result<JSValue, JavaScriptKitActorTransportError> =
                await withCheckedContinuation { continuation in
                    _ = then(
                        success: { value in
                            continuation.resume(returning: .success(value))
                            return JSValue.undefined
                        },
                        failure: { _ in
                            continuation.resume(returning: .failure(.promiseRejected))
                            return JSValue.undefined
                        }
                    )
                }
            return try result.get()
        }
    }
}
#endif
