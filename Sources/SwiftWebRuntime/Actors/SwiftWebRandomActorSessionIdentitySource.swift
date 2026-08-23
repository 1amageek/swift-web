#if SWIFTWEB_ACTORS || hasFeature(Embedded)
import ActorSystemCore

public struct SwiftWebRandomActorSessionIdentitySource: ActorSessionIdentitySource, Sendable {
    public init() {}

    public func makeSessionID() async throws -> ActorSessionID {
        var value: UInt64 = 0
        while value == 0 {
            value = UInt64.random(in: 1...UInt64.max)
        }
        return ActorSessionID(value)
    }
}
#endif
