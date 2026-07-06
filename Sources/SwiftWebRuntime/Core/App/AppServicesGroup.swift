
public struct AppServicesGroup: AppServices {
    private let services: [any AppServices]

    public init(_ services: [any AppServices]) {
        self.services = services
    }

    public func register(on application: Application) async throws {
        for service in services {
            try await service.register(on: application)
        }
    }
}
