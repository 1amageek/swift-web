enum ActorDuration {
    static func nanoseconds(_ duration: Duration?) throws -> UInt64? {
        guard let duration else {
            return nil
        }
        let components = duration.components
        guard components.seconds >= 0, components.attoseconds >= 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("A call timeout cannot be negative")
            )
        }
        let seconds = UInt64(components.seconds)
        let fractionalNanoseconds = UInt64(components.attoseconds / 1_000_000_000)
        guard seconds <= (UInt64.max - fractionalNanoseconds) / 1_000_000_000 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("The call timeout exceeds the wire range")
            )
        }
        return seconds * 1_000_000_000 + fractionalNanoseconds
    }

    static func duration(nanoseconds: UInt64?) throws -> Duration? {
        guard let nanoseconds else {
            return nil
        }
        guard nanoseconds <= UInt64(Int64.max) else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("The call timeout exceeds the runtime range")
            )
        }
        return .nanoseconds(Int64(nanoseconds))
    }
}
