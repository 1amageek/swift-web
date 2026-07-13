#if SWIFTWEB_ACTORS
public struct WebActorInvocationContext: Sendable, Equatable {
    public enum Transport: String, Sendable, Codable {
        case trusted
        case http
        case webSocket
    }

    public let transport: Transport
    public let principalID: String?
    public let sessionID: String?
    public let remoteAddress: String?
    public let peerID: String?

    public init(
        transport: Transport,
        principalID: String? = nil,
        sessionID: String? = nil,
        remoteAddress: String? = nil,
        peerID: String? = nil
    ) {
        self.transport = transport
        self.principalID = principalID
        self.sessionID = sessionID
        self.remoteAddress = remoteAddress
        self.peerID = peerID
    }

    public static let trusted = WebActorInvocationContext(transport: .trusted)

    public var isExternal: Bool {
        transport != .trusted
    }
}
#endif
