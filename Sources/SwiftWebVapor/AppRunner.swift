@_exported import SwiftWebCore
import Vapor

public struct AppRunnerInstallation: Sendable {
    private let developmentParentMonitor: Task<Void, Never>?
    private let shutdownHandlers: [@Sendable () -> Void]

    init(
        developmentParentMonitor: Task<Void, Never>?,
        shutdownHandlers: [@Sendable () -> Void]
    ) {
        self.developmentParentMonitor = developmentParentMonitor
        self.shutdownHandlers = shutdownHandlers
    }

    public func shutdown() {
        developmentParentMonitor?.cancel()
        for handler in shutdownHandlers {
            handler()
        }
    }

    public func shutdown(_ application: Application) async throws {
        shutdown()
        try await application.shutdown()
    }
}

public struct AppRunner<Definition: App> {
    private let definition: Definition
    private let clientRuntime: ClientRuntimeConfiguration?
    private let routeInstallers: [(Application) async throws -> Void]
    private let shutdownHandlers: [@Sendable () -> Void]

    public init(
        _ definition: Definition,
        clientRuntime: ClientRuntimeConfiguration? = nil,
        routeInstallers: [(Application) async throws -> Void] = [],
        shutdownHandlers: [@Sendable () -> Void] = []
    ) {
        self.definition = definition
        self.clientRuntime = clientRuntime
        self.routeInstallers = routeInstallers
        self.shutdownHandlers = shutdownHandlers
    }

    public func run() async throws {
        let application = try await Application()
        let installation: AppRunnerInstallation
        do {
            installation = try await configure(application)
        } catch {
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
        let installation = AppRunnerInstallation(
            developmentParentMonitor: devParentMonitor,
            shutdownHandlers: shutdownHandlers
        )

        do {
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
            for installer in routeInstallers {
                try await installer(application)
            }
            try await (clientRuntime ?? definition.clientRuntime).install(on: application)
            try await definition.services.register(on: application)
            try await _SceneRenderer.make(definition.body, in: .root(application))
            return installation
        } catch {
            installation.shutdown()
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
