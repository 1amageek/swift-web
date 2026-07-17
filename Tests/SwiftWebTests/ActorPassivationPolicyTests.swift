#if SWIFTWEB_ACTORS
import Testing
@testable import SwiftWebActors

@Suite struct ActorPassivationPolicyTests {
    @Test func afterIdleConvertsDurationToSeconds() {
        let policy = ActorPassivationPolicy.afterIdle(.minutes(5))
        #expect(policy.idleTimeout == 300)
    }

    @Test func hoursConvertToSeconds() {
        let policy = ActorPassivationPolicy.afterIdle(.hours(2))
        #expect(policy.idleTimeout == 7_200)
    }

    @Test func neverHasNoIdleTimeout() {
        #expect(ActorPassivationPolicy.never.idleTimeout == nil)
    }
}
#endif
