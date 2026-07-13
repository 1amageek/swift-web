#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

/// The bidirectional, multiplexed actor transport from
/// `docs/WebSocketActorTransportDesign.md`: one socket is a symmetric actor
/// message bus. Each frame is one JSON-encoded `Envelope`; either peer sends
/// invocations, responses are matched by `callID`, and server → client push
/// is an invocation targeting a client-hosted observer actor.
///
/// The transport is socket-agnostic: the owner supplies `sendFrame` (browser
/// WebSocket via JavaScriptKit, `URLSessionWebSocketTask`, a Durable Object
/// socket) and feeds inbound frames to `receive(_:)`.
public final class WebSocketActorTransport: WebActorTransport, Sendable {
    public typealias SendFrame = @Sendable (String) async throws -> Void

    private struct State: Sendable {
        var system: WebActorSystem?
        var invocationContext: WebActorInvocationContext = .trusted
        var authorization: WebActorAuthorization = .allowAll
        var activationPolicy: WebActorActivationPolicy = .unbounded
        var inboundSenderPolicy: WebSocketInboundSenderPolicy = .ignore
        var pending: [String: CheckedContinuation<ResponseEnvelope, any Error>] = [:]
        var onInboundSender: (@Sendable (String, WebSocketActorTransport) -> Void)?
    }

    private let state: Mutex<State>
    private let sendFrame: SendFrame
    private let senderID: String?

    /// - Parameters:
    ///   - senderID: The ID of the peer's local actor to address replies and
    ///     pushes to (the client passes its observer actor's ID). Stamped on
    ///     outgoing invocations so the other side learns where to push.
    ///   - sendFrame: Writes one text frame to the underlying socket.
    public init(
        senderID: String? = nil,
        inboundSenderPolicy: WebSocketInboundSenderPolicy = .ignore,
        sendFrame: @escaping SendFrame
    ) {
        self.senderID = senderID
        self.sendFrame = sendFrame
        self.state = Mutex(State(inboundSenderPolicy: inboundSenderPolicy))
    }

    /// The actor system that hosts this peer's local actors. Inbound
    /// invocations dispatch to it; without a bound system they are answered
    /// with an error response.
    public func bind(_ system: WebActorSystem) {
        state.withLock { $0.system = system }
    }

    public func bind(
        _ system: WebActorSystem,
        context: WebActorInvocationContext,
        authorization: WebActorAuthorization,
        activationPolicy: WebActorActivationPolicy = .defaults
    ) {
        state.withLock { state in
            state.system = system
            state.invocationContext = context
            state.authorization = authorization
            state.activationPolicy = activationPolicy
        }
    }

    /// Called with the sender ID of every inbound invocation that carries
    /// one. Hosts use it to route later pushes back to this socket.
    public func onInboundSender(
        _ handler: @escaping @Sendable (String, WebSocketActorTransport) -> Void
    ) {
        state.withLock { $0.onInboundSender = handler }
    }

    // MARK: - Outbound (WebActorTransport)

    public func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        // Stamp the local peer's actor ID so the other side can push back.
        let outgoing = InvocationEnvelope(
            callID: envelope.callID,
            recipientID: envelope.recipientID,
            senderID: envelope.senderID ?? senderID,
            target: envelope.target,
            genericSubstitutions: envelope.genericSubstitutions,
            arguments: envelope.arguments,
            metadata: envelope.metadata
        )
        let frame = try Self.encodeFrame(.invocation(outgoing))
        return try await withCheckedThrowingContinuation { continuation in
            state.withLock { $0.pending[outgoing.callID] = continuation }
            Task {
                do {
                    try await self.sendFrame(frame)
                } catch {
                    self.resume(callID: outgoing.callID, with: .failure(error))
                }
            }
        }
    }

    // MARK: - Inbound

    /// Feed one inbound text frame from the socket.
    public func receive(_ text: String) {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: Data(text.utf8))
        } catch {
            // A frame that is not an Envelope is a protocol error; there is
            // no callID to correlate, so it can only be surfaced locally.
            print("WebSocketActorTransport dropped an undecodable frame: \(String(describing: error))")
            return
        }

        switch envelope {
        case .response(let response):
            resume(callID: response.callID, with: .success(response))
        case .invocation(let invocation):
            let inboundSender: String?
            do {
                inboundSender = try acceptedInboundSender(for: invocation)
            } catch {
                reject(invocation, reason: String(describing: error))
                return
            }
            if let inboundSender {
                let handler = state.withLock { $0.onInboundSender }
                handler?(inboundSender, self)
            }
            let dispatch = state.withLock { state in
                (
                    system: state.system,
                    context: state.invocationContext,
                    authorization: state.authorization,
                    activationPolicy: state.activationPolicy
                )
            }
            Task {
                let response: ResponseEnvelope
                if let system = dispatch.system {
                    do {
                        response = try await system.invoke(
                            envelope: invocation,
                            context: dispatch.context,
                            authorization: dispatch.authorization,
                            activationPolicy: dispatch.activationPolicy
                        )
                    } catch let error as WebActorAuthorizationError {
                        response = ResponseEnvelope(
                            callID: invocation.callID,
                            result: .failure(.transportFailed("Actor invocation denied: \(error.reason)"))
                        )
                    } catch let error as RuntimeError {
                        response = ResponseEnvelope(callID: invocation.callID, result: .failure(error))
                    } catch {
                        response = ResponseEnvelope(
                            callID: invocation.callID,
                            result: .failure(.executionFailed(
                                "WebSocket inbound dispatch failed",
                                underlying: String(describing: error)
                            ))
                        )
                    }
                } else {
                    response = ResponseEnvelope(
                        callID: invocation.callID,
                        result: .failure(.actorNotFound(invocation.recipientID))
                    )
                }
                do {
                    try await self.sendFrame(try Self.encodeFrame(.response(response)))
                } catch {
                    // The socket failed while replying; the caller's own
                    // correlation timeout/close handling reports it.
                }
            }
        }
    }

    private func acceptedInboundSender(for invocation: InvocationEnvelope) throws -> String? {
        let policy = state.withLock { $0.inboundSenderPolicy }
        switch policy {
        case .ignore:
            return nil
        case .bind(let boundSenderID):
            if let senderID = invocation.senderID, senderID != boundSenderID {
                throw RuntimeError.transportFailed("WebSocket senderID is not bound to this connection")
            }
            return boundSenderID
        case .trustClientSupplied:
            return invocation.senderID
        }
    }

    private func reject(_ invocation: InvocationEnvelope, reason: String) {
        Task {
            let response = ResponseEnvelope(
                callID: invocation.callID,
                result: .failure(.transportFailed(reason))
            )
            do {
                try await sendFrame(try Self.encodeFrame(.response(response)))
            } catch {
            }
        }
    }

    /// Fail every in-flight call when the socket closes or errors.
    public func closed(_ error: (any Error)? = nil) {
        let pending = state.withLock { state in
            let pending = state.pending
            state.pending.removeAll()
            return pending
        }
        for continuation in pending.values {
            continuation.resume(throwing: error ?? RuntimeError.transportFailed("WebSocket closed"))
        }
    }

    private func resume(callID: String, with result: Result<ResponseEnvelope, any Error>) {
        let continuation = state.withLock { $0.pending.removeValue(forKey: callID) }
        guard let continuation else {
            return
        }
        continuation.resume(with: result)
    }

    private static func encodeFrame(_ envelope: Envelope) throws -> String {
        String(decoding: try JSONEncoder().encode(envelope), as: UTF8.self)
    }
}

/// Routes outbound invocations to the socket a peer registered from, keyed by
/// the sender IDs seen on inbound invocations. Hosts install it as the
/// system's transport so agent → observer pushes reach the right connection.
public final class WebSocketSessionRouter: WebActorTransport, Sendable {
    private let sessions = Mutex<[String: WebSocketActorTransport]>([:])

    public init() {}

    public func register(_ peerID: String, transport: WebSocketActorTransport) {
        sessions.withLock { $0[peerID] = transport }
    }

    public func unregister(transport: WebSocketActorTransport) {
        sessions.withLock { sessions in
            sessions = sessions.filter { $0.value !== transport }
        }
    }

    public func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        guard let transport = sessions.withLock({ $0[envelope.recipientID] }) else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }
        return try await transport.call(envelope)
    }
}
#endif
