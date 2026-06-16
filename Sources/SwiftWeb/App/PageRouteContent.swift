import Vapor

public struct PageRouteContent<Route: PageRoute>: AppContent {
    public init(_ route: Route.Type = Route.self) {}

    public func register(on application: Application) async throws {
        Route.register(on: application)
    }
}
