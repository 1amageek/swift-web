#if SWIFTWEB_ACTORS
import ActorSystemCore
import HTTPTypes
import SwiftWebActors
import Synchronization
@_spi(Hosting) import SwiftWebHost

enum ActorFrameInvocationEndpoint {
    static let mediaType = "application/vnd.swift-actor-frame"
    static let webSocketPath: [PathComponent] = [
        "_swiftweb",
        "actors",
        "socket",
    ]

    private static let nextConnectionID = Mutex<UInt64>(1)

    private struct RegisteredKey: RuntimeStorageKey {
        typealias Value = Bool
    }

    static func registerIfNeeded(
        in runtime: AppRuntime,
        actorSystem: WebActorSystem
    ) {
        guard runtime.requestContext.storage[RegisteredKey.self] != true else {
            return
        }
        runtime.requestContext.storage[RegisteredKey.self] = true

        runtime.routes.post("_swiftweb", "actors", "frame") { request async throws -> Response in
            try SecurityRequestValidator.validateStateChangingRequest(request)
            try requireBinaryMediaType(request.headers[.contentType])

            guard let body = try await request.collectedBody(), !body.isEmpty else {
                throw Abort(.badRequest, reason: "Actor frame body is missing")
            }
            guard let sessionID = request.session.id else {
                throw Abort(
                    .unauthorized,
                    reason: "The SwiftWeb HTTP actor transport requires a session identity"
                )
            }
            let principalID = request.session.isAuthenticated
                ? request.session.userID
                : nil
            let invocationContext = SwiftWebActorInvocationContext(
                principalID: principalID,
                sessionID: sessionID,
                remoteAddress: request.remoteAddress
            )
            let responseBytes: ActorByteBuffer?
            do {
                responseBytes = try await actorSystem.invokeActorFrame(
                    ActorByteBuffer(body),
                    context: invocationContext
                )
            } catch ActorSystemError.overloaded {
                throw Abort(.serviceUnavailable, reason: "Actor host is overloaded")
            } catch ActorSystemError.transportClosed {
                throw Abort(.serviceUnavailable, reason: "Actor transport is unavailable")
            } catch ActorSystemError.invalidFrame {
                throw Abort(.badRequest, reason: "Actor frame or peer identity is invalid")
            } catch ActorSystemError.decodingFailed {
                throw Abort(.badRequest, reason: "Actor frame is malformed")
            } catch ActorSystemError.encodingFailed {
                throw Abort(.badRequest, reason: "Actor request metadata exceeds its bounds")
            } catch ActorSystemError.transportUnavailable {
                throw Abort(
                    .internalServerError,
                    reason: "The SwiftWeb HTTP actor transport is not configured"
                )
            }
            guard let responseBytes else {
                return Response(status: .noContent)
            }
            var headers = HTTPFields()
            headers[.contentType] = mediaType
            return Response(
                status: .ok,
                headers: headers,
                body: .init(bytes: responseBytes.bytes)
            )
        }

        runtime.routes.webSocket(
            webSocketPath,
            shouldUpgrade: { request async throws -> HTTPFields? in
                guard actorSystem.hostingTransportCapability.acceptsWebSocketChannels else {
                    return nil
                }
                let security = request.securityConfiguration
                guard security.origin.allowsRequestOrigin(
                    request,
                    forwardedHeaders: security.forwardedHeaders
                ) else {
                    return nil
                }
                return [:]
            },
            onUpgrade: { request, socket async in
                do {
                    let endpoint = try makeConnectionEndpoint()
                    let invocationContext = SwiftWebActorInvocationContext(
                        principalID: request.session.isAuthenticated
                            ? request.session.userID
                            : nil,
                        sessionID: request.session.id,
                        remoteAddress: request.remoteAddress,
                        peerID: endpoint.transportSpecificAddress
                    )
                    let metadata = try SwiftWebActorInvocationContextCodec(
                        maximumEncodedBytes: actorSystem.configuration.maximumIdentityBytes,
                        maximumFieldBytes: min(
                            1_024,
                            actorSystem.configuration.maximumIdentityBytes
                        )
                    ).encode(invocationContext)
                    let channel = try SwiftWebHostActorBinaryChannel(
                        endpoint: endpoint,
                        socket: socket,
                        maximumFrameBytes: actorSystem.configuration.maximumFrameBytes,
                        maximumBufferedFrames:
                            actorSystem.configuration.maximumConcurrentInboundCalls
                    )
                    try await actorSystem.hostingTransportCapability.attach(
                        channel,
                        metadata: metadata
                    )
                } catch {
                    request.logger.error(
                        "Actor WebSocket setup failed: \(RuntimeErrorText.of(error))"
                    )
                    do {
                        try await socket.close()
                    } catch {
                        request.logger.error(
                            "Actor WebSocket close failed: \(RuntimeErrorText.of(error))"
                        )
                    }
                }
            }
        )
    }

    private static func makeConnectionEndpoint() throws -> ActorEndpoint {
        try nextConnectionID.withLock { nextID in
            guard nextID < UInt64.max else {
                throw ActorSystemError.callSequenceExhausted
            }
            let endpoint = ActorEndpoint("swiftweb.websocket.connection.\(nextID)")
            nextID += 1
            return endpoint
        }
    }

    private static func requireBinaryMediaType(_ contentType: String?) throws {
        let mediaType = contentType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .lowercased()
        guard mediaType == Self.mediaType else {
            throw Abort(.unsupportedMediaType, reason: "Binary actor frame content type is required")
        }
    }
}
#endif
