
public protocol PageRoute: Sendable {
    static func register(on routes: any RoutesBuilder)
    func register(on routes: any RoutesBuilder)
    func registerPageOwnedServices(on application: Application) async throws
    func registerPageOwnedServices(on application: Application, routes: any RoutesBuilder) async throws
}

public extension PageRoute {
    func registerPageOwnedServices(on application: Application) async throws {}

    func registerPageOwnedServices(on application: Application, routes: any RoutesBuilder) async throws {
        try await registerPageOwnedServices(on: application)
    }
}

public struct NoParams: Sendable {
    public init() {}
}

public struct NoSearchParams: Sendable {
    public init() {}
}

#if !hasFeature(Embedded)
extension NoParams: Codable {}
extension NoSearchParams: Codable {}
#endif
