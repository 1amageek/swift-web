import SwiftWebActors

/// Host-provided values that affect rendering without exposing the host's
/// server, router, storage, or lifecycle to the app definition.
@_spi(Hosting)
public struct AppRenderingContext: Sendable {
    public let serverConfiguration: ServerConfiguration
    public let clientRuntime: ClientRuntimeConfiguration?
    public let developmentHooks: SwiftWebDevelopmentHooks
    public let actorBindings: [SwiftWebActorBindingRecord]
    public let actorRouteBindings: [SwiftWebActorRouteBindingRecord]
    public let actorServiceBindings: [SwiftWebActorServiceBinding]

    public init(
        serverConfiguration: ServerConfiguration = ServerConfiguration(),
        clientRuntime: ClientRuntimeConfiguration? = nil,
        developmentHooks: SwiftWebDevelopmentHooks = .disabled,
        actorBindings: [SwiftWebActorBindingRecord] = [],
        actorRouteBindings: [SwiftWebActorRouteBindingRecord] = [],
        actorServiceBindings: [SwiftWebActorServiceBinding] = []
    ) {
        self.serverConfiguration = serverConfiguration
        self.clientRuntime = clientRuntime
        self.developmentHooks = developmentHooks
        self.actorBindings = actorBindings
        self.actorRouteBindings = actorRouteBindings
        self.actorServiceBindings = actorServiceBindings
    }
}
