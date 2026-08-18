#if SWIFTWEB_LEGACY_ACTORS
import ActorSystemCore
import Distributed
import Foundation
import Synchronization
@testable import SwiftWeb
@testable import SwiftWebActors
@testable import SwiftWebCore
import Testing

@Suite
struct SwiftWebActorSystemTests {
    @Test
    func appRuntimeShutdownReleasesTheLegacyActorRegistryExactlyOnce() async throws {
        let legacyActorSystem = LegacyWebActorSystem()
        let service = TestCounterService(actorSystem: legacyActorSystem)
        let actorSystem = try WebActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(199)
                )
            )
        )
        let runtime = AppRuntime(
            serverConfiguration: ServerConfiguration(),
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem
        )
        runtime.requireActorSystem()
        try await runtime.start()
        #expect(
            try legacyActorSystem.resolve(
                id: service.id,
                as: TestCounterService.self
            ) != nil
        )

        let firstTermination = await runtime.requestShutdown()
        let secondTermination = await runtime.requestShutdown()
        #expect(firstTermination === secondTermination)
        try await firstTermination.wait()

        #expect(throws: ActorSystemError.self) {
            _ = try legacyActorSystem.resolve(
                id: service.id,
                as: TestCounterService.self
            )
        }
    }

    @Test
    func legacyInvocationCannotJoinItsOwnShutdownAndNewWorkIsRejected() async throws {
        let system = LegacyWebActorSystem()
        let requestedTermination = Mutex<ActorSystemTermination?>(nil)
        let reentrantWaitError = Mutex<ActorSystemTerminationError?>(nil)
        let rejectedNestedInvocation = Mutex(false)
        let envelope = InvocationEnvelope(
            callID: "legacy-self-shutdown",
            recipientID: "fixture:missing",
            target: "noop",
            arguments: []
        )
        let authorization = WebActorAuthorization { _ in
            let termination = system.requestShutdown()
            requestedTermination.withLock { $0 = termination }
            do {
                try await termination.wait()
                Issue.record("Expected invocation-owned shutdown wait to fail")
            } catch let error as ActorSystemTerminationError {
                reentrantWaitError.withLock { $0 = error }
            } catch {
                Issue.record("Unexpected legacy termination error: \(error)")
            }
            do {
                _ = try await system.invoke(envelope: envelope)
                Issue.record("Expected shutdown admission to reject nested work")
            } catch let error as ActorSystemError {
                rejectedNestedInvocation.withLock {
                    $0 = error.code == .shuttingDown
                }
            } catch {
                Issue.record("Unexpected nested invocation error: \(error)")
            }
            return .deny("fixture completed")
        }

        await #expect(throws: WebActorAuthorizationError.self) {
            _ = try await system.invoke(
                envelope: envelope,
                context: .trusted,
                authorization: authorization
            )
        }

        #expect(reentrantWaitError.withLock { $0 } == .reentrantWait)
        #expect(rejectedNestedInvocation.withLock { $0 })
        let termination = try #require(requestedTermination.withLock { $0 })
        try await termination.wait()
        #expect(termination.isTerminated)
    }

    @Test
    func legacyShutdownPassivatesAndReportsPersistenceFailureAfterCleanup() async throws {
        let system = LegacyWebActorSystem()
        let client = LegacyWebActorSystem(
            transport: LoopbackWebActorTransport(system: system)
        )
        let lifecycleLog = LegacyLifecycleLog()
        let store = LegacyControlledPersistentStore()
        system.setPersistentStore(store)
        system.registerActivator(for: LegacyLifecycleProbe.self) {
            _ = LegacyLifecycleProbe(actorSystem: system, log: lifecycleLog)
        }
        let actorID = LegacyWebActorSystem.actorID(
            for: LegacyLifecycleProbe.self,
            named: "shutdown-persistence"
        )
        let remote = try $LegacyLifecycleProbeProtocol.resolve(
            id: actorID,
            using: client
        )
        #expect(try await remote.increment() == 1)
        store.failFutureSaves()

        let termination = system.requestShutdown()
        await #expect(throws: LegacyPersistenceFixtureError.saveFailed) {
            try await termination.wait()
        }

        #expect(termination.isTerminated)
        #expect(lifecycleLog.passivationCount == 1)
        #expect(store.saveAttemptCount == 2)
        #expect(throws: ActorSystemError.self) {
            _ = try system.resolve(id: actorID, as: LegacyLifecycleProbe.self)
        }
        try await client.shutdown()
    }

    @Test
    func resolvableProtocolCallsRemoteActorThroughTransport() async throws {
        let serverSystem = LegacyWebActorSystem()
        let service = TestCounterService(actorSystem: serverSystem)
        let clientSystem = LegacyWebActorSystem(transport: LoopbackWebActorTransport(system: serverSystem))

        let remote = try $TestCounterServiceProtocol.resolve(id: service.id, using: clientSystem)
        let value = try await remote.increment(by: 3)

        #expect(value == 3)
        #expect(try await service.currentValue() == 3)
    }

    @Test
    func actorMacroResolvesScopedResolvableProtocol() async throws {
        let serverSystem = LegacyWebActorSystem()
        let service = TestCounterService(actorSystem: serverSystem)
        let clientSystem = LegacyWebActorSystem(transport: LoopbackWebActorTransport(system: serverSystem))
        let contract = TestCounterService.swiftWebActorContractKey
        let scope = SwiftWebActorBindingScope(
            records: [
                SwiftWebActorBindingRecord(
                    contractKey: contract.rawValue,
                    actorID: service.id
                ),
            ],
            resolverRegistry: SwiftWebActorResolverRegistry([
                SwiftWebActorResolver(
                    legacyContract: contract,
                    actorContract: $TestCounterServiceProtocol.self
                ),
            ]),
            legacyActorSystem: clientSystem
        )

        let value = try await SwiftWebActorBindingContext.withValue(scope) {
            try await TestCounterComponent().increment(by: 5)
        }

        #expect(value == 5)
        #expect(try await service.currentValue() == 5)
    }

    @Test
    func actorBindingScopeResolvesEachContractWithItsOwnActorSystem() async throws {
        let counterSystem = LegacyWebActorSystem()
        let labelSystem = LegacyWebActorSystem()
        let counter = TestCounterService(actorSystem: counterSystem)
        let label = TestLabelService(value: "ready", actorSystem: labelSystem)
        let scope = SwiftWebActorBindingScope.empty
            .adding(counter)
            .adding(label)

        let counterService = try scope.resolve(
            (any TestCounterServiceProtocol).self,
            contract: TestCounterService.swiftWebActorContractKey
        )
        let labelService = try scope.resolve(
            (any TestLabelServiceProtocol).self,
            contract: TestLabelService.swiftWebActorContractKey
        )

        #expect(try await counterService.increment(by: 2) == 2)
        #expect(try await labelService.label() == "ready")
    }
}

@Resolvable
protocol TestCounterServiceProtocol: DistributedActor
where ActorSystem == LegacyWebActorSystem {
    distributed func increment(by amount: Int) async throws -> Int
    distributed func currentValue() async throws -> Int
}

@ResolvableActor(TestCounterServiceProtocol.self)
private distributed actor TestCounterService: TestCounterServiceProtocol {
    typealias ActorSystem = LegacyWebActorSystem

    private var value = 0

    distributed func increment(by amount: Int) async throws -> Int {
        value += amount
        return value
    }

    distributed func currentValue() async throws -> Int {
        value
    }
}

private struct TestCounterComponent: Sendable {
    @RemoteActor private var counter: any TestCounterServiceProtocol

    func increment(by amount: Int) async throws -> Int {
        try await counter.increment(by: amount)
    }
}

@Resolvable
protocol TestLabelServiceProtocol: DistributedActor
where ActorSystem == LegacyWebActorSystem {
    distributed func label() async throws -> String
}

@ResolvableActor(TestLabelServiceProtocol.self)
private distributed actor TestLabelService: TestLabelServiceProtocol {
    typealias ActorSystem = LegacyWebActorSystem

    private let value: String

    init(value: String, actorSystem: LegacyWebActorSystem) {
        self.value = value
        self.actorSystem = actorSystem
    }

    distributed func label() async throws -> String {
        value
    }
}

private struct LoopbackWebActorTransport: WebActorTransport {
    let system: LegacyWebActorSystem

    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        try await system.invoke(envelope: envelope)
    }
}

@Resolvable
protocol LegacyLifecycleProbeProtocol: DistributedActor
where ActorSystem == LegacyWebActorSystem {
    distributed func increment() async throws -> Int
}

@ResolvableActor(LegacyLifecycleProbeProtocol.self)
private distributed actor LegacyLifecycleProbe: LegacyLifecycleProbeProtocol, WebActorLifecycle {
    typealias ActorSystem = LegacyWebActorSystem

    @ActorStorage("value") private var value = 0
    private let log: LegacyLifecycleLog

    init(actorSystem: LegacyWebActorSystem, log: LegacyLifecycleLog) {
        self.actorSystem = actorSystem
        self.log = log
    }

    distributed func increment() async throws -> Int {
        value += 1
        return value
    }

    func passivating() async {
        log.recordPassivation()
    }
}

private final class LegacyLifecycleLog: Sendable {
    private let count = Mutex(0)

    var passivationCount: Int {
        count.withLock { $0 }
    }

    func recordPassivation() {
        count.withLock { $0 += 1 }
    }
}

private enum LegacyPersistenceFixtureError: Error, Equatable {
    case saveFailed
}

private final class LegacyControlledPersistentStore: WebActorPersistentStore {
    private struct State: Sendable {
        var values: [String: [String: Data]] = [:]
        var failSaves = false
        var saveAttemptCount = 0
    }

    private let state = Mutex(State())

    var saveAttemptCount: Int {
        state.withLock { $0.saveAttemptCount }
    }

    func failFutureSaves() {
        state.withLock { $0.failSaves = true }
    }

    func load(actorID: String) async throws -> [String: Data]? {
        state.withLock { $0.values[actorID] }
    }

    func save(actorID: String, values: [String: Data]) async throws {
        try state.withLock { state in
            state.saveAttemptCount += 1
            guard !state.failSaves else {
                throw LegacyPersistenceFixtureError.saveFailed
            }
            state.values[actorID] = values
        }
    }
}
#endif
