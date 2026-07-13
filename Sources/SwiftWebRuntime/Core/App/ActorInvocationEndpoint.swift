#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import SwiftWebActors

/// The host-neutral actor invocation endpoint. Registered once per app when
/// the first `ActorGroup` is lowered; decodes `InvocationEnvelope`s from the
/// raw body (the envelope wire format is plain JSON, owned by the actor
/// transport) and dispatches them on the app's actor system.
enum ActorInvocationEndpoint {
    static let path = "/_swiftweb/actors/invoke"

    private struct RegisteredKey: StorageKey {
        typealias Value = Bool
    }

    static func registerIfNeeded(on application: Application, actorSystem: WebActorSystem) {
        guard application.storage[RegisteredKey.self] != true else {
            return
        }
        application.storage[RegisteredKey.self] = true

        application.routes.post("_swiftweb", "actors", "invoke") { request async throws -> Response in
            try SecurityRequestValidator.validateStateChangingRequest(request)

            guard let body = try await request.collectedBody() else {
                throw Abort(.badRequest, reason: "Actor invocation body is missing")
            }
            let envelope = try JSONDecoder().decode(InvocationEnvelope.self, from: Data(body))
            let actorSecurity = request.application.securityConfiguration.actors
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
                    authorization: actorSecurity.authorization,
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
