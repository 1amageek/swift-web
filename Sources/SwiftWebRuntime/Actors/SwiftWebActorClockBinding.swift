#if SWIFTWEB_ACTORS || hasFeature(Embedded)
import ActorSystemCore
import Synchronization

/// Owns the one-time platform clock binding used by SwiftWeb's Embedded system.
///
/// The mutex is owned by this reference type so the binding state has one
/// storage owner even when the clock is passed through ActorSystemConfiguration
/// as an existential. Clock selection is completed before the asynchronous
/// operation begins; the lock never spans an await or an external callback.
final class SwiftWebActorClockBinding: ActorClock, Sendable {
    private struct State: Sendable {
        var installedClock: (any ActorClock)?
        var hasUsedClock = false
    }

    private let state = Mutex(State())

    func install(_ clock: any ActorClock) throws {
        try state.withLock { state in
            guard !state.hasUsedClock else {
                throw SwiftWebActorSystemConfigurationError
                    .actorClockInstallationTooLate
            }
            guard state.installedClock == nil else {
                throw SwiftWebActorSystemConfigurationError
                    .actorClockAlreadyInstalled
            }
            state.installedClock = clock
        }
    }

    func sleep(for duration: Duration) async throws {
        let clock = state.withLock { state in
            state.hasUsedClock = true
            return state.installedClock ?? ContinuousActorClock()
        }
        try await clock.sleep(for: duration)
    }
}
#endif
