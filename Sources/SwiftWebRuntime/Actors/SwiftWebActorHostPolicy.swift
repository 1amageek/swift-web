import ActorSystemCore

public protocol SwiftWebActorHostPolicy: Sendable {
    func authorize(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        isActive: Bool
    ) async throws

    func willActivate(address: ActorAddress) async throws
    func didActivate(address: ActorAddress) async throws
    func activationFailed(address: ActorAddress, error: any Error) async
    func willInvoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws
    func didInvoke(
        _ invocation: ActorInvocation,
        result: ActorInvocationResult,
        context: ActorInvocationContext
    ) async throws
    func invocationFailed(
        _ invocation: ActorInvocation,
        error: any Error,
        context: ActorInvocationContext
    ) async
    func willPassivate(address: ActorAddress) async throws
    func passivationFailed(address: ActorAddress, error: any Error) async
    func shutdown() async
}

public struct DirectSwiftWebActorHostPolicy: SwiftWebActorHostPolicy {
    public init() {}

    public func authorize(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        isActive: Bool
    ) async throws {}

    public func willActivate(address: ActorAddress) async throws {}
    public func didActivate(address: ActorAddress) async throws {}
    public func activationFailed(address: ActorAddress, error: any Error) async {}

    public func willInvoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws {}

    public func didInvoke(
        _ invocation: ActorInvocation,
        result: ActorInvocationResult,
        context: ActorInvocationContext
    ) async throws {}

    public func invocationFailed(
        _ invocation: ActorInvocation,
        error: any Error,
        context: ActorInvocationContext
    ) async {}

    public func willPassivate(address: ActorAddress) async throws {}
    public func passivationFailed(address: ActorAddress, error: any Error) async {}
    public func shutdown() async {}
}
