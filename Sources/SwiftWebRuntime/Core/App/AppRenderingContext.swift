/// Host-provided values that affect rendering without exposing the host's
/// server, router, storage, or lifecycle to the app definition.
@_spi(Hosting)
public struct AppRenderingContext: Sendable {
    public let serverConfiguration: ServerConfiguration
    public let clientRuntime: ClientRuntimeConfiguration?
    public let developmentHooks: SwiftWebDevelopmentHooks

    public init(
        serverConfiguration: ServerConfiguration = ServerConfiguration(),
        clientRuntime: ClientRuntimeConfiguration? = nil,
        developmentHooks: SwiftWebDevelopmentHooks = .disabled
    ) {
        self.serverConfiguration = serverConfiguration
        self.clientRuntime = clientRuntime
        self.developmentHooks = developmentHooks
    }
}
