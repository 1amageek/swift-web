public protocol SwiftActorSystemBootstrapProvider {
    static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type { get }
}
