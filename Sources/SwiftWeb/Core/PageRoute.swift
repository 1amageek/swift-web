import Vapor

public protocol PageRoute: Sendable {
    static func register(on routes: any RoutesBuilder)
    func register(on routes: any RoutesBuilder)
    func registerPageOwnedServices(on application: Application) async throws
}

public extension PageRoute {
    func registerPageOwnedServices(on application: Application) async throws {}
}

public struct NoParams: Codable, Sendable {
    public init() {}
}

public struct NoSearchParams: Codable, Sendable {
    public init() {}
}
