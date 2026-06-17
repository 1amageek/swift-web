import SwiftWebActors
import Vapor

public struct AppRunner<Definition: App> {
    private let definition: Definition
    private let clientRuntime: ClientRuntimeConfiguration?

    public init(_ definition: Definition, clientRuntime: ClientRuntimeConfiguration? = nil) {
        self.definition = definition
        self.clientRuntime = clientRuntime
    }

    public func run() async throws {
        let application = try await Application()
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()
        let devParentMonitor = developmentHooks.startParentMonitor(application.logger)
        defer {
            devParentMonitor?.cancel()
        }

        application.securityConfiguration = definition.security
        var middlewares = Middlewares()
        definition.security.installMiddleware(on: &middlewares)
        developmentHooks.installMiddlewares(&middlewares)
        middlewares.use(ErrorMiddleware.default(environment: application.environment))
        application.middleware = middlewares

        developmentHooks.registerRoutes(application)
        ActionGateway.register(on: application)
        WebActorGateway.register(on: application)
        do {
            try await (clientRuntime ?? definition.clientRuntime).install(on: application)
            try await definition.services.register(on: application)
            try await definition.body.register(on: application)
            try await application.run()
        } catch {
            WebActorSystem.shared.shutdown()
            try await application.shutdown()
            throw error
        }
        WebActorSystem.shared.shutdown()
        try await application.shutdown()
    }
}
