import Synchronization

public final class SequentialActorIdentitySource: ActorIdentitySource, Sendable {
    private let sequence = Mutex<UInt64>(0)

    public init() {}

    public func nextIdentity(for actorType: ActorTypeID) -> String {
        _ = actorType
        let next = sequence.withLock { sequence -> UInt64 in
            guard sequence < UInt64.max else {
                preconditionFailure("Actor identity sequence is exhausted")
            }
            sequence += 1
            return sequence
        }
        return "auto-\(next)"
    }
}
