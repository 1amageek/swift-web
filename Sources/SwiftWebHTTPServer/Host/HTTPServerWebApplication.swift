import Logging
import SwiftWebCore

/// The host-neutral application for the `swift-http-server` host.
/// Routes collect into a `WebRoutes` table; the request handler matches them
/// with `WebRouteMatcher` — no framework router.
public final class HTTPServerWebApplication: WebApplicationProtocol {
    public let logger: Logger
    public let storage = WebApplicationStorage()
    public let serverConfiguration: WebServerConfiguration
    private let webRoutes = WebRoutes()

    public init(hostname: String, port: Int, logger: Logger) {
        self.logger = logger
        self.serverConfiguration = WebServerConfiguration(hostname: hostname, port: port)
    }

    public var routes: any WebRoutesBuilder {
        webRoutes
    }

    public var collectedRoutes: [WebRoute] {
        webRoutes.all
    }
}
