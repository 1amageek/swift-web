/// Immutable host information and framework-owned state shared by every
/// request produced from one rendered app.
@_spi(Hosting)
public final class RequestRuntimeContext: Sendable {
    public let serverConfiguration: ServerConfiguration
    public let storage: RuntimeStorage

    public init(serverConfiguration: ServerConfiguration) {
        self.serverConfiguration = serverConfiguration
        self.storage = RuntimeStorage()
    }
}
