import HTTPTypes
import SwiftWeb
import SwiftWebActors
@_spi(Hosting) @testable import SwiftWebCore
import Testing

@Suite
struct SwiftWebActorFrameInvocationEndpointTests {
    #if SWIFTWEB_ACTORS
    @Test
    func browserPeerIdentitySupportsAnonymousActorRequests() throws {
        let runtime = TestWebRuntime()
        var headers = HTTPFields()
        headers[ActorFrameInvocationEndpoint.peerIDHeaderName] = "browser-peer-1"
        let request = Request(
            runtime: runtime,
            method: .post,
            headers: headers,
            remoteAddress: "127.0.0.1",
            sessionID: nil
        )

        let context = try ActorFrameInvocationEndpoint.invocationContext(for: request)

        #expect(context.peerID == "browser-peer-1")
        #expect(context.sessionID == nil)
        #expect(context.principalID == nil)
        #expect(context.remoteAddress == "127.0.0.1")
    }

    @Test
    func actorRequestWithoutPeerOrSessionIdentityIsRejected() {
        let request = Request(
            runtime: TestWebRuntime(),
            method: .post,
            sessionID: nil
        )

        #expect(throws: Abort.self) {
            try ActorFrameInvocationEndpoint.invocationContext(for: request)
        }
    }
    #endif
}
