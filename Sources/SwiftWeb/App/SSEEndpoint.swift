import Vapor

public struct SSEEndpoint<RouteType: SSERoute>: AppContent {
    private let path: String

    public init(_ route: RouteType.Type, path: String) {
        self.path = path
    }

    public func register(on application: Application) async throws {
        SSERouteBuilder.register(RouteType.self, on: application, path: path)
    }
}
