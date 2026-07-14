/// The bound address of the host server, as far as the host knows it.
/// Used to derive the request origin when no `Host` header is present.
public struct ServerConfiguration: Sendable, Equatable {
    public var hostname: String?
    public var port: Int?

    public init(hostname: String? = nil, port: Int? = nil) {
        self.hostname = hostname
        self.port = port
    }
}
