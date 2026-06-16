import Vapor

public struct EmptyAppContent: AppContent {
    public init() {}

    public func register(on application: Application) async throws {}
}
