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

    public func shutdown(_ application: Vapor.Application) async throws {
        shutdown()
        try await application.shutdown()
    }
}

public struct AppRunner<Definition: App> {
    private let definition: Definition
    private let clientRuntime: ClientRuntimeConfiguration?
    private let routeInstallers: [(SwiftWebCore.Application) async throws -> Void]
    private let shutdownHandlers: [@Sendable () -> Void]

    public init(
        _ definition: Definition,
        clientRuntime: ClientRuntimeConfiguration? = nil,
        routeInstallers: [(SwiftWebCore.Application) async throws -> Void] = [],
        shutdownHandlers: [@Sendable () -> Void] = []
    ) {
        self.definition = definition
        self.clientRuntime = clientRuntime
        self.routeInstallers = routeInstallers
        self.shutdownHandlers = shutdownHandlers
    }

    public func run() async throws {
        let application = try await Vapor.Application()
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
    public func configure(_ application: Vapor.Application) async throws -> AppRunnerInstallation {
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()
        let devParentMonitor = developmentHooks.startParentMonitor(application.logger)
        let installation = AppRunnerInstallation(
            developmentParentMonitor: devParentMonitor,
            shutdownHandlers: shutdownHandlers
        )

        do {
            let webApplication = VaporWebApplication(application)
            let security = developmentHooks.configureSecurity(definition.security)
            webApplication.securityConfiguration = security
            application.sessions.configuration = .swiftWeb

            var chain = WebMiddlewares()
            security.installMiddleware(on: &chain)
            developmentHooks.installMiddlewares(&chain)

            var middlewares = Vapor.Middlewares()
            middlewares.use(application.sessions.middleware)
            middlewares.use(VaporWebMiddlewareChainBridge(chain: chain, application: webApplication))
            middlewares.use(ErrorMiddleware.default(environment: application.environment))
            application.middleware = middlewares

            developmentHooks.registerRoutes(webApplication.routes)
            ActionGateway.register(on: webApplication)
            for installer in routeInstallers {
                try await installer(webApplication)
            }
            try await (clientRuntime ?? definition.clientRuntime).install(on: webApplication)
            try await definition.services.register(on: webApplication)
            try await _SceneRenderer.make(definition.body, in: .root(webApplication))
            webApplication.lowerPendingRoutes()
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
