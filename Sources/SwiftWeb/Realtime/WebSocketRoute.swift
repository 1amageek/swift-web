import HTTPTypes

public protocol WebSocketRoute: SendableMetatype, Sendable {
    init()

    func connect(_ context: WebSocketContext) async throws
}

public enum WebSocketRouteBuilder {
    @discardableResult
    public static func register<RouteType: WebSocketRoute>(
        _ route: RouteType.Type,
        on routes: any RoutesBuilder,
        path: String
    ) -> Route {
        register(route, on: routes, path: RoutePath(path))
    }

    @discardableResult
    public static func register<RouteType: WebSocketRoute>(
        _ route: RouteType.Type,
        on routes: any RoutesBuilder,
        path: RoutePath
    ) -> Route {
        guard SwiftWebRuntime.vaporWebSockets else {
            return routes.get(path.vaporComponents) { _ async throws -> Response in
                Response(
                    status: .notImplemented,
                    headers: [.contentType: "text/plain; charset=utf-8"],
                    body: .init(string: "WebSocket upgrade is disabled because the current Vapor 5 HTTP server does not support upgrade responses.")
                )
            }
        }

        return routes.webSocket(
            path.vaporComponents,
            shouldUpgrade: { req async throws -> HTTPFields? in
                let security = req.application.securityConfiguration
                guard security.origin.allowsRequestOrigin(req, forwardedHeaders: security.forwardedHeaders) else {
                    return nil
                }
                return [:]
            }
        ) { req, socket async in
            let requestValues = RequestValues(request: req, params: NoParams(), searchParams: NoSearchParams())
            do {
                try await RequestContext.withValue(requestValues) {
                    try await RouteType().connect(WebSocketContext(request: req, socket: socket))
                }
            } catch {
                req.logger.error("WebSocket route failed: \(String(describing: error))")
                do {
                    try await socket.close()
                } catch {
                    req.logger.error("WebSocket close failed: \(String(describing: error))")
                }
            }
        }
    }
}
