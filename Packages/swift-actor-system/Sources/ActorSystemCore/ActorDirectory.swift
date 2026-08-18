import Synchronization

public protocol ActorInvocationTarget: Sendable {
    var address: ActorAddress { get }
    var descriptor: ActorTypeDescriptor { get }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult
}

public final class ActorDirectory: Sendable {
    private struct State: Sendable {
        var targets: [ActorAddress: any ActorInvocationTarget] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    public func register(_ target: any ActorInvocationTarget) throws {
        guard target.address.type == target.descriptor.id else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation(
                    "An actor target descriptor does not match its address"
                )
            )
        }
        try target.descriptor.validate()
        try state.withLock { state in
            guard state.targets[target.address] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("An actor address is registered more than once")
                )
            }
            state.targets[target.address] = target
        }
    }

    @discardableResult
    public func unregister(address: ActorAddress) -> (any ActorInvocationTarget)? {
        state.withLock { state in
            state.targets.removeValue(forKey: address)
        }
    }

    public func target(for address: ActorAddress) -> (any ActorInvocationTarget)? {
        state.withLock { state in
            state.targets[address]
        }
    }

    public func removeAll() -> [any ActorInvocationTarget] {
        state.withLock { state in
            let removed = Array(state.targets.values)
            state.targets.removeAll(keepingCapacity: false)
            return removed
        }
    }
}
