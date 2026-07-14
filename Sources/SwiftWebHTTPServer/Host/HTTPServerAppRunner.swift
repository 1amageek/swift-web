import Logging
import NIOHTTPServer
import SwiftWebCore

/// Runs a SwiftWeb `App` on `swift-http-server` (`NIOHTTPServer`) — the
/// lightweight host from `docs/LightweightHTTPServerDecision.md`. Same app
/// model as the Vapor adapter, no framework: routes are matched with
/// `RouteMatcher`, sessions are cookie-backed, and the SwiftWeb middleware
/// chain (CORS, security, development hooks) runs around every response.
public struct HTTPServerAppRunner<Definition: App> {
    private let definition: Definition
    private let hostname: String
    private let port: Int
    private let clientRuntime: ClientRuntimeConfiguration?
    private let sessionStorage: any HTTPServerSessionStorage
    private let routeInstallers: [(Application) async throws -> Void]
    private let shutdownHandlers: [@Sendable () -> Void]

    public init(
        _ definition: Definition,
        hostname: String = "127.0.0.1",
        port: Int = 8080,
        clientRuntime: ClientRuntimeConfiguration? = nil,
        sessionStorage: any HTTPServerSessionStorage = InMemorySessionStorage(),
        routeInstallers: [(Application) async throws -> Void] = [],
        shutdownHandlers: [@Sendable () -> Void] = []
    ) {
        self.definition = definition
        self.hostname = hostname
        self.port = port
        self.clientRuntime = clientRuntime
        self.sessionStorage = sessionStorage
        self.routeInstallers = routeInstallers
        self.shutdownHandlers = shutdownHandlers
    }

    public func run() async throws {
        let logger = Logger(label: "swiftweb.host.http-server")
        let installation = try await configure(logger: logger)
        do {
            try await installation.serve()
        } catch {
            installation.shutdown()
            throw error
        }
        installation.shutdown()
    }

    /// Lowers the app onto a ready-to-serve server without starting it,
    /// mirroring `AppRunner.configure` on the Vapor host.
    public func configure(logger: Logger) async throws -> HTTPServerAppInstallation {
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()
        let devParentMonitor = developmentHooks.startParentMonitor(logger)

        do {
            let application = HTTPServerApplication(hostname: hostname, port: port, logger: logger)
            let security = developmentHooks.configureSecurity(definition.security)
            application.securityConfiguration = security

            var chain = Middlewares()
            security.installMiddleware(on: &chain)
            developmentHooks.installMiddlewares(&chain)

            developmentHooks.registerRoutes(application.routes)
            ActionGateway.register(on: application)
            for installer in routeInstallers {
                try await installer(application)
            }
            try await (clientRuntime ?? definition.clientRuntime).install(on: application)
            try await definition.services.register(on: application)
            try await _SceneRenderer.make(
                definition.body,
                in: .root(application, actorSystem: definition.actorSystem)
            )

            let handler = SwiftWebHostHTTPHandler(
                application: application,
                matcher: RouteMatcher(routes: application.collectedRoutes),
                chain: chain,
                sessionStorage: sessionStorage,
                logger: logger
            )
            let configuration = try NIOHTTPServerConfiguration(
                bindTarget: .hostAndPort(host: hostname, port: port),
                supportedHTTPVersions: [.http1_1],
                transportSecurity: .plaintext
            )
            let server = NIOHTTPServer(logger: logger, configuration: configuration)
            return HTTPServerAppInstallation(
                server: server,
                handler: handler,
                developmentParentMonitor: devParentMonitor,
                shutdownHandlers: shutdownHandlers
            )
        } catch {
            devParentMonitor?.cancel()
            for handler in shutdownHandlers {
                handler()
            }
            throw error
        }
    }
}

public struct HTTPServerAppInstallation: Sendable {
    let server: NIOHTTPServer
    let handler: SwiftWebHostHTTPHandler
    private let developmentParentMonitor: Task<Void, Never>?
    private let shutdownHandlers: [@Sendable () -> Void]

    init(
        server: NIOHTTPServer,
        handler: SwiftWebHostHTTPHandler,
        developmentParentMonitor: Task<Void, Never>?,
        shutdownHandlers: [@Sendable () -> Void]
    ) {
        self.server = server
        self.handler = handler
        self.developmentParentMonitor = developmentParentMonitor
        self.shutdownHandlers = shutdownHandlers
    }

    public func serve() async throws {
        try await server.serve(handler: handler)
    }

    public func shutdown() {
        developmentParentMonitor?.cancel()
        for handler in shutdownHandlers {
            handler()
        }
    }
}
