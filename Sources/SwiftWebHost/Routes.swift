import HTTPTypes
import Synchronization

/// Collects the routes an app registers. Host adapters read `all` after the
/// app's scenes are lowered and register each route on their native router.
public final class Routes: RoutesBuilder, Sendable {
    private let storage = Mutex<[Route]>([])

    public init() {}

    public var all: [Route] {
        storage.withLock { $0 }
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: BodyStreamStrategy,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        let route = Route(method: method, path: path, bodyStrategy: body, handler: .http(handler))
        storage.withLock { routes in
            precondition(
                !routes.contains { $0.method == method && $0.path.elementsEqual(path) && $0.isHTTP },
                "Duplicate route registration: \(method) \(path.map { $0.description }.joined(separator: "/")) is already registered"
            )
            routes.append(route)
        }
        return route
    }

    @discardableResult
    public func webSocket(
        _ path: [PathComponent],
        shouldUpgrade: @escaping @Sendable (Request) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (Request, any WebSocketChannel) async -> Void
    ) -> Route {
        let route = Route(
            method: .get,
            path: path,
            bodyStrategy: .collect,
            handler: .webSocket(shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
        )
        storage.withLock { $0.append(route) }
        return route
    }

    public func grouped(_ path: [PathComponent]) -> any RoutesBuilder {
        guard !path.isEmpty else {
            return self
        }
        return GroupedRoutes(root: self, prefix: path)
    }
}

/// A prefixed view over `Routes`; registrations resolve to absolute paths.
final class GroupedRoutes: RoutesBuilder {
    let root: Routes
    let prefix: [PathComponent]

    init(root: Routes, prefix: [PathComponent]) {
        self.root = root
        self.prefix = prefix
    }

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: BodyStreamStrategy,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        root.on(method, prefix + path, body: body, use: handler)
    }

    @discardableResult
    func webSocket(
        _ path: [PathComponent],
        shouldUpgrade: @escaping @Sendable (Request) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (Request, any WebSocketChannel) async -> Void
    ) -> Route {
        root.webSocket(prefix + path, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
    }

    func grouped(_ path: [PathComponent]) -> any RoutesBuilder {
        guard !path.isEmpty else {
            return self
        }
        return GroupedRoutes(root: root, prefix: prefix + path)
    }
}
