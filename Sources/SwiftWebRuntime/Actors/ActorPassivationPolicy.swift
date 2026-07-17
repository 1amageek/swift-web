#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// Controls when an idle virtual actor is passivated: its instance is
/// evicted from memory while its `@ActorStorage` grain state stays durable,
/// so the next message re-activates it transparently.
///
///     ActorGroup(scope: .user) { ChatAgent(actorSystem: $0) }
///         .passivation(.afterIdle(.minutes(5)))
///
/// Passivation is a per-contract override of the host's
/// `WebActorActivationPolicy.idleTimeout`; the tighter of the two wins for
/// the contract it is registered on.
public struct ActorPassivationPolicy: Sendable, Equatable {
    /// Seconds of inactivity after which the actor instance is evicted,
    /// or `nil` to keep instances alive until the host-level policy acts.
    public let idleTimeout: TimeInterval?

    private init(idleTimeout: TimeInterval?) {
        self.idleTimeout = idleTimeout
    }

    /// Passivate instances idle for at least the given duration.
    public static func afterIdle(_ duration: Duration) -> ActorPassivationPolicy {
        ActorPassivationPolicy(idleTimeout: duration.timeInterval)
    }

    /// Never passivate on idleness; only host-level limits apply.
    public static let never = ActorPassivationPolicy(idleTimeout: nil)
}

extension Duration {
    /// The duration expressed as a `TimeInterval` in seconds.
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1e18
    }

    /// A duration given in minutes.
    public static func minutes(_ minutes: Int) -> Duration {
        .seconds(minutes * 60)
    }

    /// A duration given in hours.
    public static func hours(_ hours: Int) -> Duration {
        .seconds(hours * 3_600)
    }
}
#endif
