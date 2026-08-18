@preconcurrency import ActorRuntime
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class LegacyJSONActorGateway: ActorTransport, Sendable {
    private struct Pending: Sendable {
        let legacyCallID: String
        let method: LegacyActorMethodBridge
        let continuation: CheckedContinuation<ResponseEnvelope, Error>
        var invocationWasYielded: Bool
    }

    private struct DeferredCancellation: Sendable {
        let endpoint: ActorEndpoint
        var invocationWasYielded: Bool
    }

    private struct State: Sendable {
        var started = false
        var stopped = false
        var nextSequence: UInt64 = 0
        var pending: [ActorCallID: Pending] = [:]
        var deferredCancellations: [ActorCallID: DeferredCancellation] = [:]
    }

    public let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    public let transportID: ActorTransportID
    private let streamContinuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let sessionID: ActorSessionID
    private let descriptors: [LegacyActorBridgeDescriptor]
    private let maximumPendingCalls: Int
    private let maximumArgumentCount: Int
    private let maximumPayloadBytes: Int
    private let maximumIdentityBytes: Int
    private let maximumMetadataEntries: Int
    private let maximumMetadataBytes: Int
    private let state = Mutex(State())

    public init(
        transportID: ActorTransportID = ActorTransportID("legacy-json"),
        sessionID: ActorSessionID,
        descriptors: [LegacyActorBridgeDescriptor],
        maximumPendingCalls: Int = 1_024,
        maximumBufferedFrames: Int = 64,
        maximumArgumentCount: Int = 1_024,
        maximumPayloadBytes: Int = 1_000_000,
        maximumIdentityBytes: Int = 4_096,
        maximumMetadataEntries: Int = 128,
        maximumMetadataBytes: Int = 16_384
    ) throws {
        guard sessionID.rawValue != 0,
              maximumPendingCalls > 0,
              maximumBufferedFrames > 0,
              maximumArgumentCount >= 0,
              maximumPayloadBytes >= 0,
              maximumIdentityBytes > 0,
              maximumMetadataEntries >= 0,
              maximumMetadataBytes >= 0
        else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Legacy actor transport configuration is invalid")
            )
        }
        var contracts: Set<String> = []
        for descriptor in descriptors {
            guard contracts.insert(descriptor.legacyContract).inserted else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("A legacy actor contract is registered more than once")
                )
            }
        }
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream(
            bufferingPolicy: .bufferingOldest(maximumBufferedFrames)
        )
        self.incoming = stream.stream
        self.streamContinuation = stream.continuation
        self.transportID = transportID
        self.sessionID = sessionID
        self.descriptors = descriptors
        self.maximumPendingCalls = maximumPendingCalls
        self.maximumArgumentCount = maximumArgumentCount
        self.maximumPayloadBytes = maximumPayloadBytes
        self.maximumIdentityBytes = maximumIdentityBytes
        self.maximumMetadataEntries = maximumMetadataEntries
        self.maximumMetadataBytes = maximumMetadataBytes
    }

    public func start() async throws {
        try state.withLock { state in
            guard !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            guard !state.started else {
                throw ActorSystemError.alreadyStarted
            }
            state.started = true
        }
    }

    public func handle(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        try validateEnvelopeBounds(envelope)
        guard envelope.genericSubstitutions.isEmpty else {
            throw RuntimeError.invalidEnvelope(
                "Generic legacy actor invocations are not portable"
            )
        }
        let matches = descriptors.compactMap { descriptor -> (
            LegacyActorBridgeDescriptor,
            ActorAddress
        )? in
            descriptor.address(recipientID: envelope.recipientID).map { (descriptor, $0) }
        }
        guard matches.count == 1, let (descriptor, address) = matches.first else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }
        guard let method = descriptor.method(target: envelope.target) else {
            throw RuntimeError.methodNotFound(envelope.target)
        }
        let arguments = try method.decodeArguments(envelope.arguments)
        let callID = try nextCallID()
        let frame = ActorInboundFrame(
            frame: .invocation(
                ActorInvocationFrame(
                    callID: callID,
                    invocation: ActorInvocation(
                        recipient: address,
                        method: method.methodID,
                        schemaFingerprint: descriptor.schemaFingerprint,
                        payload: arguments
                    ),
                    remainingTimeoutNanoseconds: nil
                )
            ),
            transport: transportID,
            replyEndpoint: replyEndpoint(for: callID)
        )

        return try await withTaskCancellationHandler {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    do {
                        try register(
                            callID: callID,
                            pending: Pending(
                                legacyCallID: envelope.callID,
                                method: method,
                                continuation: continuation,
                                invocationWasYielded: false
                            )
                        )
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                    let wasCancelled = withUnsafeCurrentTask { $0?.isCancelled ?? false }
                    if wasCancelled {
                        fail(
                            callID: callID,
                            error: ActorSystemError.cancelled,
                            defersCancellation: true
                        )
                        return
                    }
                    switch streamContinuation.yield(frame) {
                    case .enqueued:
                        markInvocationYielded(callID: callID)
                    case .dropped:
                        fail(
                            callID: callID,
                            error: ActorSystemError.overloaded,
                            defersCancellation: false
                        )
                    case .terminated:
                        fail(
                            callID: callID,
                            error: ActorSystemError.transportClosed,
                            defersCancellation: false
                        )
                    @unknown default:
                        fail(
                            callID: callID,
                            error: ActorSystemError.transportClosed,
                            defersCancellation: false
                        )
                    }
                }
            } catch {
                emitDeferredCancellation(callID: callID)
                throw error
            }
        } onCancel: {
            fail(
                callID: callID,
                error: ActorSystemError.cancelled,
                defersCancellation: true
            )
        }
    }

    public func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint
    ) async throws {
        guard case .result(let result) = frame else {
            throw ActorSystemError.transportUnavailable(transportID)
        }
        guard endpoint == replyEndpoint(for: result.callID) else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("A legacy actor result used the wrong reply endpoint")
            )
        }
        let pending = state.withLock { state in
            state.pending.removeValue(forKey: result.callID)
        }
        guard let pending else {
            return
        }
        do {
            let legacyResult: InvocationResult
            switch result.outcome {
            case .success(let invocationResult):
                if let data = try pending.method.encodeResult(invocationResult.payload) {
                    legacyResult = .success(data)
                } else {
                    legacyResult = .void
                }
            case .systemFailure(let failure):
                legacyResult = .failure(runtimeError(for: failure.code))
            case .applicationFailure:
                legacyResult = .failure(
                    .executionFailed(
                        "portableApplicationError",
                        underlying: "The legacy protocol cannot decode this typed error"
                    )
                )
            }
            pending.continuation.resume(
                returning: ResponseEnvelope(
                    callID: pending.legacyCallID,
                    result: legacyResult
                )
            )
        } catch {
            pending.continuation.resume(throwing: error)
        }
    }

    public func shutdown() async {
        let pending = state.withLock { state -> [Pending] in
            guard !state.stopped else {
                return []
            }
            state.stopped = true
            state.started = false
            let pending = Array(state.pending.values)
            state.pending.removeAll(keepingCapacity: false)
            state.deferredCancellations.removeAll(keepingCapacity: false)
            return pending
        }
        streamContinuation.finish()
        for call in pending {
            call.continuation.resume(throwing: ActorSystemError.transportClosed)
        }
    }

    private func nextCallID() throws -> ActorCallID {
        try state.withLock { state in
            guard state.started, !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            guard state.nextSequence < UInt64.max else {
                throw ActorSystemError.callSequenceExhausted
            }
            state.nextSequence += 1
            return ActorCallID(session: sessionID, sequence: state.nextSequence)
        }
    }

    private func register(callID: ActorCallID, pending: Pending) throws {
        try state.withLock { state in
            guard state.started, !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            guard state.pending.count < maximumPendingCalls,
                  state.deferredCancellations.count
                    < maximumPendingCalls - state.pending.count
            else {
                throw ActorSystemError.overloaded
            }
            guard state.pending[callID] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("A legacy call identifier is already pending")
                )
            }
            state.pending[callID] = pending
        }
    }

    private func fail(
        callID: ActorCallID,
        error: any Error,
        defersCancellation: Bool
    ) {
        let pending = state.withLock { state -> Pending? in
            guard let pending = state.pending.removeValue(forKey: callID) else {
                return nil
            }
            if defersCancellation {
                state.deferredCancellations[callID] = DeferredCancellation(
                    endpoint: replyEndpoint(for: callID),
                    invocationWasYielded: pending.invocationWasYielded
                )
            }
            return pending
        }
        guard let pending else {
            return
        }
        pending.continuation.resume(throwing: error)
    }

    private func markInvocationYielded(callID: ActorCallID) {
        state.withLock { state in
            if var pending = state.pending[callID] {
                pending.invocationWasYielded = true
                state.pending[callID] = pending
                return
            }
            if var cancellation = state.deferredCancellations[callID] {
                cancellation.invocationWasYielded = true
                state.deferredCancellations[callID] = cancellation
            }
        }
    }

    private func emitDeferredCancellation(callID: ActorCallID) {
        let cancellation = state.withLock { state in
            state.deferredCancellations.removeValue(forKey: callID)
        }
        guard let cancellation, cancellation.invocationWasYielded else {
            return
        }
        let result = streamContinuation.yield(
            ActorInboundFrame(
                frame: .cancellation(callID),
                transport: transportID,
                replyEndpoint: cancellation.endpoint
            )
        )
        switch result {
        case .enqueued:
            return
        case .dropped, .terminated:
            // The legacy caller has already observed cancellation. The
            // bounded compatibility transport cannot guarantee delivery of a
            // later control frame after overload or closure.
            return
        @unknown default:
            return
        }
    }

    private func replyEndpoint(for callID: ActorCallID) -> ActorEndpoint {
        ActorEndpoint("legacy-call-\(callID.sequence)")
    }

    private func validateEnvelopeBounds(_ envelope: InvocationEnvelope) throws {
        guard !envelope.callID.isEmpty,
              envelope.callID.utf8.count <= maximumIdentityBytes,
              !envelope.recipientID.isEmpty,
              envelope.recipientID.utf8.count <= maximumIdentityBytes,
              !envelope.target.isEmpty,
              envelope.target.utf8.count <= maximumIdentityBytes
        else {
            throw RuntimeError.invalidEnvelope("Legacy actor identity exceeds its bound")
        }
        if let senderID = envelope.senderID {
            guard !senderID.isEmpty,
                  senderID.utf8.count <= maximumIdentityBytes
            else {
                throw RuntimeError.invalidEnvelope("Legacy sender identity exceeds its bound")
            }
        }
        guard envelope.arguments.count <= maximumArgumentCount else {
            throw RuntimeError.invalidEnvelope("Legacy actor argument count exceeds its bound")
        }
        var payloadBytes = 0
        for argument in envelope.arguments {
            guard argument.count <= maximumPayloadBytes - payloadBytes else {
                throw RuntimeError.invalidEnvelope("Legacy actor payload exceeds its bound")
            }
            payloadBytes += argument.count
        }
        guard envelope.metadata.headers.count <= maximumMetadataEntries,
              !envelope.metadata.version.isEmpty
        else {
            throw RuntimeError.invalidEnvelope("Legacy actor metadata exceeds its bound")
        }
        var metadataBytes = 0
        func validateMetadataField(_ field: String) throws {
            let count = field.utf8.count
            guard count <= maximumIdentityBytes,
                  count <= maximumMetadataBytes - metadataBytes
            else {
                throw RuntimeError.invalidEnvelope("Legacy actor metadata exceeds its bound")
            }
            metadataBytes += count
        }
        try validateMetadataField(envelope.metadata.version)
        for (key, value) in envelope.metadata.headers {
            guard !key.isEmpty else {
                throw RuntimeError.invalidEnvelope("Legacy actor metadata contains an empty key")
            }
            try validateMetadataField(key)
            try validateMetadataField(value)
        }
    }

    private func runtimeError(for code: ActorSystemErrorCode) -> RuntimeError {
        switch code {
        case .actorNotFound:
            .actorNotFound("portable actor")
        case .targetUnavailable:
            .methodNotFound("portable actor method")
        case .timeout:
            .transportFailed("The portable actor invocation timed out")
        case .unsupportedWireVersion:
            .versionMismatch(expected: "1", actual: "unsupported")
        case .transportClosed, .transportUnavailable:
            .transportFailed("The portable actor transport is unavailable")
        case .invalidFrame, .decodingFailed, .encodingFailed:
            .serializationFailed("The portable actor payload is invalid")
        default:
            .executionFailed(
                "portableActorInvocation",
                underlying: "Portable actor system error code \(code.rawValue)"
            )
        }
    }
}
