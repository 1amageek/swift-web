import Vapor

public protocol AppContent {
    func register(on application: Application) async throws
}
