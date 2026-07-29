
public protocol AppServices: SendableMetatype {
    func register(on application: Application) async throws
}
