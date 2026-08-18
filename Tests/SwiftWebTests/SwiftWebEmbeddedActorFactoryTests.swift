#if !SWIFTWEB_ACTORS
import ActorSystemCore
import Synchronization
@testable import SwiftWebActors
import Testing

@Suite
struct SwiftWebEmbeddedActorFactoryTests {
    #if hasFeature(Embedded)
    @Test
    func embeddedIdentitySourceConsumesTheRequestedVirtualAddress() {
        let expected = ActorAddress(
            type: ActorTypeID(high: 524, low: 525),
            identity: "requested-virtual-identity"
        )
        let source = SwiftWebEmbeddedActorIdentitySource()

        let identity = SwiftWebActorActivationIdentity.withValue(expected) {
            source.nextIdentity(for: expected.type)
        }

        #expect(identity == expected.identity)
    }
    #endif

    @Test
    func factoryRejectsAnActorCreatedWithADifferentIdentity() async {
        let expected = ActorAddress(
            type: SwiftWebEmbeddedActorFactoryFixture.actorTypeDescriptor.id,
            identity: "expected-activation"
        )
        let actual = ActorAddress(
            type: expected.type,
            identity: "unexpected-activation"
        )
        let passivated = Mutex<ActorAddress?>(nil)
        let factory = SwiftWebActorFactory(
            SwiftWebEmbeddedActorFactoryFixture.self,
            activate: { _ in
                SwiftWebEmbeddedActorFactoryFixture(id: actual)
            },
            passivate: { address in
                passivated.withLock { $0 = address }
            }
        )

        do {
            try await factory.activate(address: expected)
            Issue.record("Expected embedded activation identity validation to fail")
        } catch let error as ActorSystemError {
            #expect(error == .activationFailed)
        } catch {
            Issue.record("Unexpected embedded activation error: \(error)")
        }
        #expect(passivated.withLock { $0 } == actual)
    }
}

private struct SwiftWebEmbeddedActorFactoryFixture: ActorSystemReference {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 520, low: 521),
        schemaFingerprint: ActorSchemaFingerprint(high: 522, low: 523),
        methods: []
    )

    let id: ActorAddress
    let actorSystem: Void = ()

    static func resolve(
        id: ActorAddress,
        using actorSystem: Void
    ) throws -> Self {
        _ = actorSystem
        return Self(id: id)
    }
}
#endif
