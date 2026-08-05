import Logging
import NIOHTTPServer
@_spi(Hosting) import SwiftWebCore

/// Connects a rendered SwiftWeb app to `NIOHTTPServer`.
public struct HTTPServerHost: Sendable {
    private let hostname: String
    private let port: Int
    private let clientRuntime: ClientRuntimeConfiguration?
    private let sessionStorage: any HTTPServerSessionStorage

    public init(
        hostname: String = "127.0.0.1",
        port: Int = 8080,
        clientRuntime: ClientRuntimeConfiguration? = nil,
        sessionStorage: any HTTPServerSessionStorage = InMemorySessionStorage()
    ) {
        self.hostname = hostname
        self.port = port
        self.clientRuntime = clientRuntime
        self.sessionStorage = sessionStorage
    }

    /// Renders an app and returns a configured server installation without
    /// starting the server loop.
    public func render<AppType: App>(
        _ app: AppType,
        logger: Logger = Logger(label: "swiftweb.host.http-server")
    ) async throws -> HTTPServerAppInstallation {
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()
        let parentMonitor = developmentHooks.startParentMonitor(logger)

        do {
            let renderedApp = try await AppRenderer.render(
                app,
                in: AppRenderingContext(
                    serverConfiguration: ServerConfiguration(
                        hostname: hostname,
                        port: port
                    ),
                    clientRuntime: clientRuntime,
                    developmentHooks: developmentHooks
                )
            )
            let handler = SwiftWebHostHTTPHandler(
                renderedApp: renderedApp,
                sessionStorage: sessionStorage,
                logger: logger
            )
            let configuration = try NIOHTTPServerConfiguration(
                bindTarget: .hostAndPort(host: hostname, port: port),
                supportedHTTPVersions: [.http1_1],
                transportSecurity: .plaintext
            )
            let server = NIOHTTPServer(
                logger: logger,
                configuration: configuration
            )
            return HTTPServerAppInstallation(
                server: server,
                handler: handler,
                developmentParentMonitor: parentMonitor
            )
        } catch {
            parentMonitor?.cancel()
            throw error
        }
    }

    public func run<AppType: App>(_ app: AppType) async throws {
        let installation = try await render(app)
        do {
            try await installation.serve()
        } catch {
            installation.shutdown()
            throw error
        }
        installation.shutdown()
    }
}
