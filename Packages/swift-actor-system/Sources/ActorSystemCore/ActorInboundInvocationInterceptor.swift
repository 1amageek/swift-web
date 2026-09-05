import Synchronization

public struct ActorInvocationExecution: Sendable {
    private let executeValue: @Sendable () async throws -> ActorInvocationResult
    private let forwardValue: (@Sendable () async throws -> ActorInvocationResult)?
    private let state: ActorInvocationExecutionState

    public init(
        _ execute: @escaping @Sendable () async throws -> ActorInvocationResult
    ) {
        self.executeValue = execute
        self.forwardValue = nil
        self.state = ActorInvocationExecutionState()
    }

    public init(
        execute: @escaping @Sendable () async throws -> ActorInvocationResult,
        forward: @escaping @Sendable () async throws -> ActorInvocationResult
    ) {
        self.executeValue = execute
        self.forwardValue = forward
        self.state = ActorInvocationExecutionState()
    }

    public func callAsFunction() async throws -> ActorInvocationResult {
        try claim()
        return try await executeValue()
    }

    /// Starts a routed outbound call instead of executing the local target.
    /// Authorization belongs to the interceptor selecting this operation.
    /// Local execution and forwarding share the same exactly-once claim.
    public func forward() async throws -> ActorInvocationResult {
        try claim()
        guard let forwardValue else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Forwarding is unavailable for this invocation")
            )
        }
        return try await forwardValue()
    }

    private func claim() throws {
        guard state.claim() else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("An inbound invocation execution was called more than once")
            )
        }
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
