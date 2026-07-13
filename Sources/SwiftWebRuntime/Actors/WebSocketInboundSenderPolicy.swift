#if SWIFTWEB_ACTORS
public enum WebSocketInboundSenderPolicy: Sendable, Equatable {
    /// Ignore any sender ID carried in the frame. This is the safe default for
    /// peers that do not derive a connection identity server-side.
    case ignore

    /// Accept only the sender ID bound to this connection by the host.
    case bind(String)

    /// Compatibility escape hatch for fully trusted tests or private transports.
    case trustClientSupplied
}
#endif
