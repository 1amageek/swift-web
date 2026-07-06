import HTTPTypes
import Synchronization

/// Collects the routes an app registers. Host adapters read `all` after the
/// app's scenes are lowered and register each route on their native router.
public final class WebRoutes: WebRoutesBuilder, Sendable {
    private let storage = Mutex<[WebRoute]>([])

    public init() {}

    public var all: [WebRoute] {
        storage.withLock { $0 }
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: [WebPathComponent],
        body: WebBodyStreamStrategy,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        let route = WebRoute(method: method, path: path, bodyStrategy: body, handler: .http(handler))
        storage.withLock { $0.append(route) }
        return route
    }

    @discardableResult
    public func webSocket(
        _ path: [WebPathComponent],
        shouldUpgrade: @escaping @Sendable (WebRequest) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (WebRequest, any WebSocketChannel) async -> Void
    ) -> WebRoute {
        let route = WebRoute(
            method: .get,
            path: path,
            bodyStrategy: .collect,
            handler: .webSocket(shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
        )
        storage.withLock { $0.append(route) }
        return route
    }

    public func grouped(_ path: [WebPathComponent]) -> any WebRoutesBuilder {
        guard !path.isEmpty else {
            return self
        }
        return WebGroupedRoutes(root: self, prefix: path)
    }
}

/// A prefixed view over `WebRoutes`; registrations resolve to absolute paths.
struct WebGroupedRoutes: WebRoutesBuilder {
    let root: WebRoutes
    let prefix: [WebPathComponent]

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [WebPathComponent],
        body: WebBodyStreamStrategy,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        root.on(method, prefix + path, body: body, use: handler)
    }

    @discardableResult
    func webSocket(
        _ path: [WebPathComponent],
        shouldUpgrade: @escaping @Sendable (WebRequest) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (WebRequest, any WebSocketChannel) async -> Void
    ) -> WebRoute {
        root.webSocket(prefix + path, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
    }

    func grouped(_ path: [WebPathComponent]) -> any WebRoutesBuilder {
        guard !path.isEmpty else {
            return self
        }
        return WebGroupedRoutes(root: root, prefix: prefix + path)
    }
}
