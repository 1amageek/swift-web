public protocol PageRoute: Sendable {
    static func register(on routes: any RoutesBuilder)
}

public struct NoParams: Codable, Sendable {
    public init() {}
}

public struct NoSearchParams: Codable, Sendable {
    public init() {}
}
