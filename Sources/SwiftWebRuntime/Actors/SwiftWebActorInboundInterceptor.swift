#if SWIFTWEB_ACTORS
import ActorSystemCore

struct SwiftWebActorInboundInterceptor: ActorLocalInvocationClaiming {
    private let configuredInterceptor: any ActorInboundInvocationInterceptor
    private let actorHost: SwiftWebActorHost

    init(
        configuredInterceptor: any ActorInboundInvocationInterceptor,
        actorHost: SwiftWebActorHost
    ) {
        self.configuredInterceptor = configuredInterceptor
        self.actorHost = actorHost
    }

    func claimsLocalInvocation(for recipient: ActorAddress) async -> Bool {
        if await configuredInterceptor.claimsLocalInvocation(for: recipient) {
            return true
        }
        return await actorHost.claimsLocalInvocation(for: recipient)
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        try await configuredInterceptor.intercept(
            invocation,
            context: context,
            execution: ActorInvocationExecution {
                try await actorHost.intercept(
                    invocation,
                    context: context,
                    execution: execution
                )
            }
        )
    }
}
#endif
