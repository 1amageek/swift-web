#if SWIFTWEB_ACTORS
import ActorSystemCore
import ActorSystemEmbedded
import Foundation
import Synchronization
import Testing
@testable import SwiftWebActors

@Suite
struct ActorSystemFacadeParityTests {
    @Test
    func commonConstructionAndLifecycleSurfaceWorksAcrossBackends() async throws {
        let source = FacadeParityIdentitySource()
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(
                ActorSessionID(97)
            )
        )

        let native = try WebActorSystem(
            identitySource: source,
            configuration: configuration
        )
        let embedded = EmbeddedActorSystem(
            identitySource: source,
            configuration: configuration
        )

        #expect(native.configuration.maximumFrameBytes == configuration.maximumFrameBytes)
        #expect(embedded.configuration.maximumFrameBytes == configuration.maximumFrameBytes)

        try await native.start()
        try await embedded.start()
        try await native.shutdown()
        try await embedded.shutdown()
    }

    @Test
    func directWebActorSystemShutdownFinalizesItsOwnedHost() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let passivationCount = Mutex(0)
        let factory = SwiftWebActorFactory(
            FacadeParityHostedReference.self,
            activate: { address in
                FacadeParityHostedReference(id: address)
            },
            passivate: { _ in
                passivationCount.withLock { $0 += 1 }
            }
        )
        try await host.register(factory)
        let address = ActorAddress(
            type: FacadeParityHostedReference.actorTypeDescriptor.id,
            identity: "owned-host"
        )
        #expect(factory.descriptor.id == address.type)
        let claimsBeforeStart = await host.claimsLocalInvocation(for: address)
        #expect(claimsBeforeStart)
        let system = try WebActorSystem(
            actorHost: host,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(98)
                )
            )
        )
        try await system.start()
        #expect(system.actorHost === host)
        let claimsAfterStart = await host.claimsLocalInvocation(for: address)
        #expect(claimsAfterStart)
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(990),
            schemaFingerprint: FacadeParityHostedReference
                .actorTypeDescriptor.schemaFingerprint,
            payload: ActorByteBuffer()
        )
        _ = try await system.configuration.inboundInterceptor.intercept(
            invocation,
            context: ActorInvocationContext(
                callID: ActorCallID(
                    session: ActorSessionID(98),
                    sequence: 1
                ),
                origin: .local,
                remainingTimeout: nil
            ),
            execution: ActorInvocationExecution {
                ActorInvocationResult()
            }
        )
        let claimsAfterActivation = await host.claimsLocalInvocation(for: address)
        #expect(claimsAfterActivation)

        try await system.shutdown()

        #expect(passivationCount.withLock { $0 } == 1)
        let claimsAfterShutdown = await host.claimsLocalInvocation(for: address)
        #expect(!claimsAfterShutdown)
        await #expect(throws: SwiftWebActorHostError.self) {
            _ = try await host.intercept(
                invocation,
                context: ActorInvocationContext(
                    callID: ActorCallID(
                        session: ActorSessionID(98),
                        sequence: 2
                    ),
                    origin: .local,
                    remainingTimeout: nil
                ),
                execution: ActorInvocationExecution {
                    ActorInvocationResult()
                }
            )
        }
    }

    @Test
    func directWebActorSystemShutdownPropagatesHostPersistenceFailure() async throws {
        let store = FacadeParityFailingPersistentStore()
        let host = SwiftWebActorHost(
            authorization: .allowAll,
            persistentStore: store
        )
        let passivationCount = Mutex(0)
        try await host.register(
            SwiftWebActorFactory(
                FacadeParityHostedReference.self,
                activate: { address in
                    FacadeParityHostedReference(id: address)
                },
                passivate: { _ in
                    passivationCount.withLock { $0 += 1 }
                }
            )
        )
        let system = try WebActorSystem(
            actorHost: host,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(99)
                )
            )
        )
        try await system.start()
        let address = ActorAddress(
            type: FacadeParityHostedReference.actorTypeDescriptor.id,
            identity: "failing-owned-host"
        )
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(992),
            schemaFingerprint: FacadeParityHostedReference
                .actorTypeDescriptor.schemaFingerprint,
            payload: ActorByteBuffer()
        )
        _ = try await system.configuration.inboundInterceptor.intercept(
            invocation,
            context: ActorInvocationContext(
                callID: ActorCallID(
                    session: ActorSessionID(99),
                    sequence: 1
                ),
                origin: .local,
                remainingTimeout: nil
            ),
            execution: ActorInvocationExecution { ActorInvocationResult() }
        )
        store.failFutureSaves()

        await #expect(throws: FacadeParityPersistenceError.saveFailed) {
            try await system.shutdown()
        }

        #expect(passivationCount.withLock { $0 } == 1)
        #expect(await !host.claimsLocalInvocation(for: address))
    }
}

private struct FacadeParityIdentitySource: ActorIdentitySource {
    func nextIdentity(for actorType: ActorTypeID) -> String {
        "fixture-\(actorType.high)-\(actorType.low)"
    }
}

private struct FacadeParityHostedReference: ActorSystemReference {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 988, low: 989),
        schemaFingerprint: ActorSchemaFingerprint(high: 990, low: 991),
        methods: []
    )

    let id: ActorAddress
    let actorSystem: Void = ()
    @ActorStorage("value") private var value = 1

    static func resolve(
        id: ActorAddress,
        using actorSystem: Void
    ) throws -> FacadeParityHostedReference {
        _ = actorSystem
        return FacadeParityHostedReference(id: id)
    }
}

private enum FacadeParityPersistenceError: Error, Equatable {
    case saveFailed
}

private final class FacadeParityFailingPersistentStore: WebActorPersistentStore {
    private let failSaves = Mutex(false)

    func failFutureSaves() {
        failSaves.withLock { $0 = true }
    }

    func load(actorID: String) async throws -> [String: Data]? {
        _ = actorID
        return nil
    }

    func save(actorID: String, values: [String: Data]) async throws {
        _ = (actorID, values)
        if failSaves.withLock({ $0 }) {
            throw FacadeParityPersistenceError.saveFailed
        }
    }
}
#endif
