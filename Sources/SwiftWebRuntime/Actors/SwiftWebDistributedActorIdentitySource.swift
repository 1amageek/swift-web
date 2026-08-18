#if SWIFTWEB_ACTORS
import ActorSystemCore
import ActorSystemDistributed

public final class SwiftWebDistributedActorIdentitySource: ActorIdentitySource, Sendable {
    private let fallback: any ActorIdentitySource

    public init(
        fallback: any ActorIdentitySource = SequentialActorIdentitySource()
    ) {
        self.fallback = fallback
    }

    public func nextIdentity(for actorType: ActorTypeID) -> String {
        if let pending = SwiftWebActorActivationIdentity.take(actorType: actorType) {
            return pending.identity
        }
        return fallback.nextIdentity(for: actorType)
    }
}
#endif
