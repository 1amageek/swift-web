
public struct EmptyAppServices: AppServices {
    public init() {}

    public func register(on application: Application) async throws {}
}
