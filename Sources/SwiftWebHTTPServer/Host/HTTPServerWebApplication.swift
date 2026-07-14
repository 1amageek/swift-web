import Logging
import SwiftWebCore

/// The host-neutral application for the `swift-http-server` host.
/// Routes collect into a `Routes` table; the request handler matches them
/// with `RouteMatcher` — no framework router.
public final class HTTPServerApplication: ApplicationProtocol {
    public let logger: Logger
    public let storage = ApplicationStorage()
    public let serverConfiguration: ServerConfiguration
    private let webRoutes = Routes()

    public init(hostname: String, port: Int, logger: Logger) {
        self.logger = logger
        self.serverConfiguration = ServerConfiguration(hostname: hostname, port: port)
    }

    public var routes: any RoutesBuilder {
        webRoutes
    }

    public var collectedRoutes: [Route] {
        webRoutes.all
    }
}
