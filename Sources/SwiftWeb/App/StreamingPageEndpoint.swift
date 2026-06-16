import Vapor

public struct StreamingPageEndpoint<Page: StreamingPage>: AppContent {
    private let path: String

    public init(_ page: Page.Type, path: String) {
        self.path = path
    }

    public func register(on application: Application) async throws {
        StreamingPageRoute.register(Page.self, on: application, path: path)
    }
}
