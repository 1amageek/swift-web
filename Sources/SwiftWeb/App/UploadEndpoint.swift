import Vapor

public struct UploadEndpoint<Action: UploadAction>: AppContent {
    private let path: String
    private let body: HTTPBodyStreamStrategy

    public init(
        _ action: Action.Type,
        path: String,
        body: HTTPBodyStreamStrategy = .collect
    ) {
        self.path = path
        self.body = body
    }

    public func register(on application: Application) async throws {
        UploadRoute.post(Action.self, on: application, path: path, body: body)
    }
}
