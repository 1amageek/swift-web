import Synchronization

public struct ActorInvocationExecution: Sendable {
    private let executeValue: @Sendable () async throws -> ActorInvocationResult
    private let state: ActorInvocationExecutionState

    public init(
        _ execute: @escaping @Sendable () async throws -> ActorInvocationResult
    ) {
        self.executeValue = execute
        self.state = ActorInvocationExecutionState()
    }

    public func callAsFunction() async throws -> ActorInvocationResult {
        guard state.claim() else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("An inbound invocation execution was called more than once")
            )
        }
        return try await executeValue()
    }
}

private final class ActorInvocationExecutionState: Sendable {
    private let claimed = Mutex(false)

    func claim() -> Bool {
        claimed.withLock { claimed in
            guard !claimed else {
                return false
            }
            claimed = true
            return true
        }
    }
}

public protocol ActorInboundInvocationInterceptor: Sendable {
    func claimsLocalInvocation(for recipient: ActorAddress) async -> Bool

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult
}

public extension ActorInboundInvocationInterceptor {
    func claimsLocalInvocation(for recipient: ActorAddress) async -> Bool {
        _ = recipient
        return false
    }
}

/// Claims actor addresses that are owned locally even when their invocation
/// target has not been materialized yet.
///
/// A claiming interceptor must either activate and execute the local target or
/// return an error. Once claimed, Core never falls back to an outbound route.
public protocol ActorLocalInvocationClaiming: ActorInboundInvocationInterceptor {}

public struct DirectActorInboundInvocationInterceptor: ActorInboundInvocationInterceptor {
    public init() {}

    public func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        try await execution()
    }
}
