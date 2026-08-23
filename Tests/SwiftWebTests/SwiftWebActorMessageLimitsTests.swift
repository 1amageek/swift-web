#if SWIFTWEB_ACTORS
@testable import SwiftWebActors
import Testing

@Suite
struct SwiftWebActorMessageLimitsTests {
    @Test
    func sharedRuntimeCarriesACompleteFourMebibyteTypedPayload() {
        #expect(
            WebActorSystem.shared.configuration.maximumPayloadBytes
                > 4 * 1_024 * 1_024
        )
        #expect(
            WebActorSystem.shared.configuration.maximumFrameBytes
                > WebActorSystem.shared.configuration.maximumPayloadBytes
        )
    }
}
#endif
