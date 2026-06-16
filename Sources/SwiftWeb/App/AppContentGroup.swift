import Vapor

public struct AppContentGroup: AppContent {
    private let components: [any AppContent]

    public init(_ components: [any AppContent]) {
        self.components = components
    }

    public func register(on application: Application) async throws {
        for component in components {
            try await component.register(on: application)
        }
    }
}
