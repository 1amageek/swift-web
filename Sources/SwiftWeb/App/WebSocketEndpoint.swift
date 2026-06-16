import Vapor

public struct WebSocketEndpoint<RouteType: WebSocketRoute>: AppContent {
    private let path: String

    public init(_ route: RouteType.Type, path: String) {
        self.path = path
    }

    public func register(on application: Application) async throws {
        WebSocketRouteBuilder.register(RouteType.self, on: application, path: path)
    }
}
