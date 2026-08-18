#if SWIFTWEB_LEGACY_ACTORS
@preconcurrency import ActorSystemCompatibility
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import HTTPTypes
import SwiftWebActors
@_spi(Hosting) import SwiftWebHost

/// The host-neutral actor invocation endpoint. Registered once per app when
/// the first `ActorGroup` is lowered; decodes `InvocationEnvelope`s from the
/// raw body (the envelope wire format is plain JSON, owned by the actor
/// transport) and dispatches them on the app's actor system.
enum LegacyActorInvocationEndpoint {
    static let path = "/_swiftweb/actors/invoke"

    private struct RegisteredKey: RuntimeStorageKey {
        typealias Value = Bool
    }

    static func registerIfNeeded(in runtime: AppRuntime, actorSystem: LegacyWebActorSystem) {
        guard runtime.requestContext.storage[RegisteredKey.self] != true else {
            return
        }
        runtime.requestContext.storage[RegisteredKey.self] = true

        runtime.routes.post("_swiftweb", "actors", "invoke") { request async throws -> Response in
            try SecurityRequestValidator.validateStateChangingRequest(request)

            guard let body = try await request.collectedBody() else {
                throw Abort(.badRequest, reason: "Actor invocation body is missing")
            }
            let envelope: InvocationEnvelope
            do {
                envelope = try JSONDecoder().decode(
                    InvocationEnvelope.self,
                    from: Data(body)
                )
            } catch {
                throw Abort(
                    .badRequest,
                    reason: "Actor invocation body is malformed"
                )
            }
            let actorSecurity = request.securityConfiguration.actors
            let context = WebActorInvocationContext(
                transport: .http,
                principalID: request.session.userID,
                sessionID: request.session.id,
                remoteAddress: request.remoteAddress
            )
            let response: ResponseEnvelope
            do {
                response = try await actorSystem.invoke(
                    envelope: envelope,
                    context: context,
                    authorization: actorSecurity.legacyAuthorization,
                    activationPolicy: actorSecurity.activation
                )
            } catch let error as WebActorAuthorizationError {
                var headers = HTTPFields()
                headers[.contentType] = "text/plain; charset=utf-8"
                return Response(
                    status: .forbidden,
                    headers: headers,
                    body: .init(string: error.reason)
                )
            }

            var headers = HTTPFields()
            headers[.contentType] = "application/json; charset=utf-8"
            return Response(
                status: .ok,
                headers: headers,
                body: .init(data: try JSONEncoder().encode(response))
            )
        }
    }
}
#endif
