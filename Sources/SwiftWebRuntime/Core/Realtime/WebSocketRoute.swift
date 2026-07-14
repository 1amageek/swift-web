import SwiftWebBrowserRuntime
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
        guard SwiftWebRuntime.hostWebSockets else {
            return routes.get(path.webComponents) { _ async throws -> Response in
                var headers = HTTPFields()
                headers[.contentType] = "text/plain; charset=utf-8"
                return Response(
                    status: .notImplemented,
                    headers: headers,
                    body: .init(string: "WebSocket upgrade is disabled because the current host HTTP server does not support upgrade responses.")
                )
            }
        }

        return routes.webSocket(
            path.webComponents,
            shouldUpgrade: { req async throws -> HTTPFields? in
                let security = req.application.securityConfiguration
                guard security.origin.allowsRequestOrigin(req, forwardedHeaders: security.forwardedHeaders) else {
                    return nil
                }
                return [:]
            },
            onUpgrade: { req, channel async in
                let requestValues = RequestValues(request: req, params: NoParams(), searchParams: NoSearchParams())
                do {
                    try await RequestContext.withValue(requestValues) {
                        try await RouteType().connect(WebSocketContext(request: req, channel: channel))
                    }
                } catch {
                    req.logger.error("WebSocket route failed: \(RuntimeErrorText.of(error))")
                    do {
                        try await channel.close()
                    } catch {
                        req.logger.error("WebSocket close failed: \(RuntimeErrorText.of(error))")
                    }
                }
            }
        )
    }
}
