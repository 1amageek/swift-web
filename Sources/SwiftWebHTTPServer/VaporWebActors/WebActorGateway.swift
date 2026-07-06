@preconcurrency import ActorRuntime
import Foundation
import HTTPTypes
import SwiftWebActors
import SwiftWebCore
import SwiftWebVapor

public enum WebActorGateway {
    public static let path = "/_swiftweb/actors/invoke"

    @discardableResult
    public static func register(on application: Application) -> Route {
        application.routes.post("_swiftweb", "actors", "invoke") { req async throws -> Response in
            try SecurityRequestValidator.validateStateChangingRequest(req)

            guard let body = try await req.collectedBody() else {
                throw Abort(.badRequest, reason: "Actor invocation body is missing")
            }
            // The envelope wire format is owned by the actor transport: plain
            // JSON coding, matching the client's `JSONEncoder` exactly.
            let envelope = try JSONDecoder().decode(InvocationEnvelope.self, from: Data(body))
            let response = try await WebActorSystem.shared.invoke(envelope: envelope)

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

public extension App {
    static func runWithWebActorGateway() async throws {
        try await AppRunner(
            Self(),
            routeInstallers: [
                { application in
                    _ = WebActorGateway.register(on: application)
                },
            ],
            shutdownHandlers: [
                {
                    WebActorSystem.shared.shutdown()
                },
            ]
        ).run()
    }

    static func runWithWebActorGateway(clientRuntime: ClientRuntimeConfiguration) async throws {
        try await AppRunner(
            Self(),
            clientRuntime: clientRuntime,
            routeInstallers: [
                { application in
                    _ = WebActorGateway.register(on: application)
                },
            ],
            shutdownHandlers: [
                {
                    WebActorSystem.shared.shutdown()
                },
            ]
        ).run()
    }
}
