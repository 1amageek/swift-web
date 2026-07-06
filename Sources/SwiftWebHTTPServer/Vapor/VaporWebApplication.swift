import Logging
import SwiftWebCore
import Synchronization
import Vapor

/// Vapor-backed conformance of the host-neutral application contract.
/// Collects the app's routes during scene lowering; `lowerPendingRoutes()`
/// registers them on the wrapped Vapor application afterwards.
public final class VaporWebApplication: WebApplicationProtocol {
    public let vapor: Vapor.Application
    public let storage = WebApplicationStorage()
    private let webRoutes = WebRoutes()
    private let loweredRouteCount = Mutex(0)

    public init(_ vapor: Vapor.Application) {
        self.vapor = vapor
    }

    /// A Vapor middleware that runs the given SwiftWeb middleware chain,
    /// for hosts that assemble their Vapor middleware stack manually.
    public func middlewareBridge(_ chain: WebMiddlewares) -> any Vapor.Middleware {
        VaporWebMiddlewareChainBridge(chain: chain, application: self)
    }

    /// Registers every collected route that has not been lowered yet on the
    /// Vapor router. Called once after the app's scenes are rendered, and
    /// again whenever routes are registered later (e.g. from tests).
    public func lowerPendingRoutes() {
        let routes = webRoutes.all
        let start = loweredRouteCount.withLock { count in
            let start = count
            count = routes.count
            return start
        }
        guard start < routes.count else {
            return
        }
        VaporRouteLowering.lower(Array(routes[start...]), onto: self)
    }

    public var logger: Logger {
        vapor.logger
    }

    public var routes: any WebRoutesBuilder {
        webRoutes
    }

    public var collectedRoutes: [WebRoute] {
        webRoutes.all
    }

    public var serverConfiguration: WebServerConfiguration {
        WebServerConfiguration(
            hostname: vapor.serverConfiguration.hostname,
            port: vapor.serverConfiguration.port
        )
    }
}
