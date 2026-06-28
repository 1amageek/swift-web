@preconcurrency import ActorRuntime
import Foundation
import NIOCore
import SwiftWebActors
import SwiftWebCore
import SwiftWebVapor
import Vapor

public enum WebActorGateway {
    public static let path = "/_swiftweb/actors/invoke"

    @discardableResult
    public static func register(on application: Application) -> Route {
        application.post("_swiftweb", "actors", "invoke") { req async throws -> Response in
            try SecurityRequestValidator.validateStateChangingRequest(req)

            guard let body = req.body.data else {
                throw Abort(.badRequest, reason: "Actor invocation body is missing")
            }
            let envelope = try JSONDecoder().decode(
                InvocationEnvelope.self,
                from: Data(buffer: body)
            )
            let response = try await WebActorSystem.shared.invoke(envelope: envelope)

            return Response(
                status: .ok,
                headers: [.contentType: "application/json; charset=utf-8"],
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
