
public protocol PageRoute: Sendable {
    static func register(on routes: any RoutesBuilder)
    func register(on routes: any RoutesBuilder)
    func _registerPageActions(in context: PageActionRegistrationContext) async throws
}

public extension PageRoute {
    func _registerPageActions(in context: PageActionRegistrationContext) async throws {}
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
