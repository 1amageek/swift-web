@_exported import SwiftWebCore
import SwiftWebActors
import Vapor

public struct AppRunnerInstallation: Sendable {
    private let developmentParentMonitor: Task<Void, Never>?

    init(developmentParentMonitor: Task<Void, Never>?) {
        self.developmentParentMonitor = developmentParentMonitor
    }

    public func shutdown() {
        developmentParentMonitor?.cancel()
        WebActorSystem.shared.shutdown()
    }

    public func shutdown(_ application: Application) async throws {
        shutdown()
        try await application.shutdown()
    }
}

public struct AppRunner<Definition: App> {
    private let definition: Definition
    private let clientRuntime: ClientRuntimeConfiguration?

    public init(_ definition: Definition, clientRuntime: ClientRuntimeConfiguration? = nil) {
        self.definition = definition
        self.clientRuntime = clientRuntime
    }

    public func run() async throws {
        let application = try await Application()
        let installation: AppRunnerInstallation
        do {
            installation = try await configure(application)
        } catch {
            WebActorSystem.shared.shutdown()
            try await application.shutdown()
            throw error
        }

        do {
            try await application.run()
        } catch {
            try await installation.shutdown(application)
            throw error
        }
        try await installation.shutdown(application)
    }

    @discardableResult
    public func configure(_ application: Application) async throws -> AppRunnerInstallation {
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()
        let devParentMonitor = developmentHooks.startParentMonitor(application.logger)

        let security = developmentHooks.configureSecurity(definition.security)
        application.securityConfiguration = security
        application.sessions.configuration = .swiftWeb
        var middlewares = Middlewares()
        middlewares.use(application.sessions.middleware)
        security.installMiddleware(on: &middlewares)
        developmentHooks.installMiddlewares(&middlewares)
        middlewares.use(ErrorMiddleware.default(environment: application.environment))
        application.middleware = middlewares

        developmentHooks.registerRoutes(application)
        ActionGateway.register(on: application)
        WebActorGateway.register(on: application)
        do {
            try await (clientRuntime ?? definition.clientRuntime).install(on: application)
            try await definition.services.register(on: application)
            try await _SceneRenderer.make(definition.body, in: .root(application))
            return AppRunnerInstallation(developmentParentMonitor: devParentMonitor)
        } catch {
            AppRunnerInstallation(developmentParentMonitor: devParentMonitor).shutdown()
            throw error
        }
    }
}

private extension SessionsConfiguration {
    static var swiftWeb: SessionsConfiguration {
        SessionsConfiguration(cookieName: "swiftweb-session") { sessionID in
            HTTPCookies.Value(
                string: sessionID.string,
                maxAge: 60 * 60 * 24 * 7,
                path: "/",
                isSecure: false,
                isHTTPOnly: true,
                sameSite: .lax
            )
        }
    }
}

public extension App {
    static func run() async throws {
        try await AppRunner(Self()).run()
    }

    static func run(clientRuntime: ClientRuntimeConfiguration) async throws {
        try await AppRunner(Self(), clientRuntime: clientRuntime).run()
    }

    static func main() async throws {
        try await run()
    }
}
