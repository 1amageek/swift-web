public protocol ActorTransport: Sendable {
    var incoming: AsyncThrowingStream<ActorInboundFrame, Error> { get }

    func start() async throws

    func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint
    ) async throws

    /// Sends a frame and reports when it crosses the transport's dispatch
    /// boundary. Request/reply transports override this requirement so
    /// cancellation can distinguish an unsent call from an in-flight call.
    func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint,
        onDispatched: @escaping @Sendable () -> Void
    ) async throws

    /// Installs an admission callback for partial endpoint failure.
    ///
    /// The callback returns after Core accepts or rejects ownership of cleanup;
    /// the transport must not own or join the admitted cleanup operation.
    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async

    func shutdown() async
}

public extension ActorTransport {
    func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint,
        onDispatched: @escaping @Sendable () -> Void
    ) async throws {
        try await send(frame, to: endpoint)
        onDispatched()
    }

    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        _ = handler
    }
}

/// Reports when a frame has crossed the transport's dispatch boundary even if
/// `send` remains suspended while waiting for a request/reply response.
public protocol ActorTransportDispatchReporting: ActorTransport {
}

/// Reports partial link loss from a transport that keeps serving other
/// endpoints. Single-endpoint transports report closure by terminating their
/// `incoming` stream instead.
public protocol ActorEndpointLifecycleReportingTransport: ActorTransport {}

public protocol ActorSessionIdentitySource: Sendable {
    func makeSessionID() async throws -> ActorSessionID
}

public struct UnavailableActorSessionIdentitySource: ActorSessionIdentitySource {
    public init() {}

    public func makeSessionID() async throws -> ActorSessionID {
        throw ActorSystemError.sessionIdentityUnavailable
    }
}

public struct FixedActorSessionIdentitySource: ActorSessionIdentitySource {
    public let sessionID: ActorSessionID

    public init(_ sessionID: ActorSessionID) {
        self.sessionID = sessionID
    }

    public func makeSessionID() async throws -> ActorSessionID {
        sessionID
    }
}
