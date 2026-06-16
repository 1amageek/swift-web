import Vapor

public struct Redirect: AppContent, Sendable {
    private let source: RoutePath
    private let destination: String

    public init(
        _ source: String,
        to destination: String
    ) {
        self.source = RoutePath(source)
        self.destination = destination
    }

    public func register(on application: Application) async throws {
        let destination = self.destination
        application.get(source.vaporComponents) { request in
            request.redirect(to: destination)
        }
    }
}
