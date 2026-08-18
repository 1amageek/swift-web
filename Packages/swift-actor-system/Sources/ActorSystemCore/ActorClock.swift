public protocol ActorClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct ActorClockUnavailable: Error, Hashable, Sendable {
    public init() {}
}

/// The default wall clock on platforms where Swift Concurrency provides a
/// cancellable sleep primitive. Embedded platforms must inject an `ActorClock`
/// backed by their platform timer when call deadlines are enabled.
public struct ContinuousActorClock: ActorClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
#if hasFeature(Embedded)
        _ = duration
        throw ActorClockUnavailable()
#else
        guard duration > .zero else {
            return
        }
        let components = duration.components
        let seconds = UInt64(components.seconds)
        let fractionalNanoseconds = UInt64(
            components.attoseconds / 1_000_000_000
        )
        let nanoseconds: UInt64
        if seconds > (UInt64.max - fractionalNanoseconds) / 1_000_000_000 {
            nanoseconds = UInt64.max
        } else {
            nanoseconds = seconds * 1_000_000_000 + fractionalNanoseconds
        }
        try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
#endif
    }
}
