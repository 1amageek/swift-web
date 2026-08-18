public struct ActorSystemConfiguration: Sendable {
    public let sessionIdentitySource: any ActorSessionIdentitySource
    public let maximumInFlightCalls: Int
    public let maximumConcurrentInboundCalls: Int
    public let maximumRetainedInboundResults: Int
    public let maximumTransportEndpoints: Int
    public let maximumFrameBytes: Int
    public let maximumPayloadBytes: Int
    public let maximumIdentityBytes: Int
    public let maximumNestingDepth: Int
    public let maximumCollectionElements: Int
    public let clock: any ActorClock
    public let inboundInterceptor: any ActorInboundInvocationInterceptor

    public init(
        sessionIdentitySource: any ActorSessionIdentitySource,
        maximumInFlightCalls: Int = 1_024,
        maximumConcurrentInboundCalls: Int = 64,
        maximumRetainedInboundResults: Int = 4_096,
        maximumTransportEndpoints: Int = 1_024,
        maximumFrameBytes: Int = 1_048_576,
        maximumPayloadBytes: Int = 1_000_000,
        maximumIdentityBytes: Int = 4_096,
        maximumNestingDepth: Int = 64,
        maximumCollectionElements: Int = 100_000,
        clock: any ActorClock = ContinuousActorClock(),
        inboundInterceptor: any ActorInboundInvocationInterceptor = DirectActorInboundInvocationInterceptor()
    ) {
        self.sessionIdentitySource = sessionIdentitySource
        self.maximumInFlightCalls = maximumInFlightCalls
        self.maximumConcurrentInboundCalls = maximumConcurrentInboundCalls
        self.maximumRetainedInboundResults = maximumRetainedInboundResults
        self.maximumTransportEndpoints = maximumTransportEndpoints
        self.maximumFrameBytes = maximumFrameBytes
        self.maximumPayloadBytes = maximumPayloadBytes
        self.maximumIdentityBytes = maximumIdentityBytes
        self.maximumNestingDepth = maximumNestingDepth
        self.maximumCollectionElements = maximumCollectionElements
        self.clock = clock
        self.inboundInterceptor = inboundInterceptor
    }

    public var portableDecodingOptions: ActorPortableDecodingOptions {
        ActorPortableDecodingOptions(
            maximumCollectionElements: maximumCollectionElements,
            maximumNestingDepth: maximumNestingDepth
        )
    }

    public func replacingInboundInterceptor(
        _ inboundInterceptor: any ActorInboundInvocationInterceptor
    ) -> ActorSystemConfiguration {
        ActorSystemConfiguration(
            sessionIdentitySource: sessionIdentitySource,
            maximumInFlightCalls: maximumInFlightCalls,
            maximumConcurrentInboundCalls: maximumConcurrentInboundCalls,
            maximumRetainedInboundResults: maximumRetainedInboundResults,
            maximumTransportEndpoints: maximumTransportEndpoints,
            maximumFrameBytes: maximumFrameBytes,
            maximumPayloadBytes: maximumPayloadBytes,
            maximumIdentityBytes: maximumIdentityBytes,
            maximumNestingDepth: maximumNestingDepth,
            maximumCollectionElements: maximumCollectionElements,
            clock: clock,
            inboundInterceptor: inboundInterceptor
        )
    }
}
