#if SWIFTWEB_ACTORS
import Testing
@testable import SwiftWebActors

@Suite struct ActorScopeTests {
    @Test func userScopeDerivesPrincipalPrefix() throws {
        let context = WebActorInvocationContext(transport: .http, principalID: "u1")
        let prefix = try ActorScope.user.derivedNamePrefix(context: context)
        #expect(prefix == ["user", "u1"])
    }

    @Test func userScopeFailsWithoutPrincipal() {
        let context = WebActorInvocationContext(transport: .http)
        #expect(throws: ActorScopeError.missingContextValue(segment: "user", field: "principalID")) {
            try ActorScope.user.derivedNamePrefix(context: context)
        }
    }

    @Test func tenantScopeDerivesTenantPrefix() throws {
        let context = WebActorInvocationContext(transport: .http, tenantID: "acme")
        let prefix = try ActorScope.tenant.derivedNamePrefix(context: context)
        #expect(prefix == ["tenant", "acme"])
    }

    @Test func sessionScopeFailsWithoutSession() {
        let context = WebActorInvocationContext(transport: .http, principalID: "u1")
        #expect(throws: ActorScopeError.missingContextValue(segment: "session", field: "sessionID")) {
            try ActorScope.session.derivedNamePrefix(context: context)
        }
    }

    @Test func applicationScopeUsesConstantKey() throws {
        let prefix = try ActorScope.application.derivedNamePrefix(
            context: WebActorInvocationContext(transport: .http)
        )
        #expect(prefix == ["app", "app"])
    }

    @Test func compositionConcatenatesDerivedSegments() throws {
        let context = WebActorInvocationContext(transport: .http, principalID: "u1", tenantID: "acme")
        let scope = ActorScope.tenant + ActorScope.user
        let prefix = try scope.derivedNamePrefix(context: context)
        #expect(prefix == ["tenant", "acme", "user", "u1"])
    }

    @Test func addressedSegmentEndsDerivedPrefix() throws {
        let context = WebActorInvocationContext(transport: .http, principalID: "u1")
        let scope = ActorScope.user + ActorScope.addressed(authorization: .allowAll)
        let prefix = try scope.derivedNamePrefix(context: context)
        #expect(prefix == ["user", "u1"])
    }

    @Test func transientScopeComposesAsTransient() {
        let scope = ActorScope.transient + ActorScope.user
        #expect(scope.isTransient)
        #expect(!ActorScope.user.isTransient)
    }
}
#endif
