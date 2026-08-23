import ActorSystemCore
import Foundation
import Synchronization
@testable import SwiftWebActors
import Testing

@Suite
struct SwiftWebActorHostTests {
    @Test
    func invocationContextIsTaskLocalToHostedExecution() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let expected = SwiftWebActorInvocationContext(
            principalID: "calendar-page-reader",
            sessionID: "database-runtime-1",
            tenantID: "calendar",
            remoteAddress: "cloudflare-service-binding",
            peerID: "page-runtime-1"
        )
        let metadata = try SwiftWebActorInvocationContextCodec().encode(expected)
        let observed = Mutex<SwiftWebActorInvocationContext?>(nil)

        #expect(SwiftWebActorInvocationContext.current == nil)
        try await host.registerBound(
            address: Self.fixtureInvocation(identity: "context").recipient
        )
        _ = try await host.intercept(
            Self.fixtureInvocation(identity: "context"),
            context: ActorInvocationContext(
                callID: ActorCallID(
                    session: ActorSessionID(500),
                    sequence: 1
                ),
                origin: .remote(
                    transport: .swiftWebHTTP,
                    endpoint: ActorEndpoint("cloudflare-do://database")
                ),
                remainingTimeout: nil,
                metadata: metadata
            ),
            execution: ActorInvocationExecution {
                observed.withLock {
                    $0 = SwiftWebActorInvocationContext.current
                }
                return ActorInvocationResult()
            }
        )

        #expect(observed.withLock { $0 } == expected)
        #expect(SwiftWebActorInvocationContext.current == nil)
        try await host.shutdown()
    }

    @Test
    func factoryRejectsAnActorCreatedWithADifferentIdentity() async {
        let expected = ActorAddress(
            type: SwiftWebActorHostFixtureReference.actorTypeDescriptor.id,
            identity: "expected-activation"
        )
        let actual = ActorAddress(
            type: expected.type,
            identity: "unexpected-activation"
        )
        let passivated = Mutex<ActorAddress?>(nil)
        let factory = SwiftWebActorFactory(
            SwiftWebActorHostFixtureReference.self,
            activate: { _ in
                SwiftWebActorHostFixtureReference(id: actual)
            },
            passivate: { address in
                passivated.withLock { $0 = address }
            }
        )

        do {
            _ = try await factory.activate(address: expected)
            Issue.record("Expected activation identity validation to fail")
        } catch let error as ActorSystemError {
            #expect(error == .activationFailed)
        } catch {
            Issue.record("Unexpected activation error: \(error)")
        }
        #expect(passivated.withLock { $0 } == actual)
    }

    @Test
    func invalidInvocationBoundFailsConfigurationSeal() async throws {
        let host = SwiftWebActorHost(maximumConcurrentInvocations: 0)

        await #expect(throws: ActorSystemError.self) {
            try await host.sealConfiguration()
        }

        try await host.shutdown()
    }

    @Test
    func cancellationWhileWaitingForActorGateDoesNotExecute() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let address = ActorAddress(
            type: ActorTypeID(high: 501, low: 502),
            identity: "gate-cancellation"
        )
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(503),
            schemaFingerprint: ActorSchemaFingerprint(high: 504, low: 505),
            payload: ActorByteBuffer()
        )
        let probe = SwiftWebActorGateProbe()
        try await host.registerBound(address: address)

        let first = Task {
            try await host.intercept(
                invocation,
                context: Self.context(sequence: 1),
                execution: ActorInvocationExecution {
                    await probe.executeFirst()
                }
            )
        }
        await eventuallySwiftWebActorHost {
            await probe.firstExecutionStarted
        }

        let cancelled = Task {
            try await host.intercept(
                invocation,
                context: Self.context(sequence: 2),
                execution: ActorInvocationExecution {
                    await probe.executeSecond()
                }
            )
        }
        cancelled.cancel()
        await probe.releaseFirst()
        _ = try await first.value

        do {
            _ = try await cancelled.value
            Issue.record("Expected the waiting invocation to be cancelled")
        } catch let error as ActorSystemError {
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("Unexpected waiting invocation error: \(error)")
        }
        #expect(await probe.executionCount == 1)
        try await host.shutdown()
    }

    @Test
    func shutdownCancelsAndJoinsReminderTasks() async throws {
        let delivery = SwiftWebReminderDeliveryProbe()
        let store = try InProcessSwiftWebActorReminderStore { reminder in
            await delivery.deliver(reminder)
        }
        let host = SwiftWebActorHost(
            authorization: .allowAll,
            reminderStore: store
        )
        let address = ActorAddress(
            type: ActorTypeID(high: 506, low: 507),
            identity: "reminder-shutdown"
        )
        try await host.reminders(for: address).set("future", in: .seconds(60))

        try await host.shutdown()

        #expect(await delivery.deliveryCount == 0)
        await #expect(throws: SwiftWebActorReminderError.self) {
            try await host.reminders(for: address).set("late", in: .seconds(0))
        }
        await #expect(throws: ActorSystemError.self) {
            try await store.pending(actorAddress: address)
        }
    }

    @Test
    func shutdownReportsPersistenceFailureAfterPassivatingAndReleasingActor() async throws {
        let store = SwiftWebFailingShutdownPersistentStore()
        let host = SwiftWebActorHost(
            authorization: .allowAll,
            persistentStore: store
        )
        let passivationCount = Mutex(0)
        let factory = SwiftWebActorFactory(
            SwiftWebPersistentHostFixtureReference.self,
            activate: { address in
                SwiftWebPersistentHostFixtureReference(id: address)
            },
            passivate: { _ in
                passivationCount.withLock { $0 += 1 }
            }
        )
        try await host.register(factory)
        let invocation = ActorInvocation(
            recipient: ActorAddress(
                type: SwiftWebPersistentHostFixtureReference.actorTypeDescriptor.id,
                identity: "persistence-failure"
            ),
            method: ActorMethodID(531),
            schemaFingerprint: SwiftWebPersistentHostFixtureReference
                .actorTypeDescriptor.schemaFingerprint,
            payload: ActorByteBuffer()
        )
        _ = try await host.intercept(
            invocation,
            context: Self.context(sequence: 11),
            execution: ActorInvocationExecution { ActorInvocationResult() }
        )
        store.failFutureSaves()

        let termination = await host.requestShutdown()
        await #expect(throws: SwiftWebHostPersistenceFixtureError.saveFailed) {
            try await termination.wait()
        }

        #expect(termination.isTerminated)
        #expect(passivationCount.withLock { $0 } == 1)
        #expect(store.saveAttemptCount == 2)
        await #expect(throws: SwiftWebActorHostError.self) {
            _ = try await host.intercept(
                invocation,
                context: Self.context(sequence: 12),
                execution: ActorInvocationExecution { ActorInvocationResult() }
            )
        }
    }

    @Test
    func reminderStoreAppliesBoundedAdmission() async throws {
        let store = try InProcessSwiftWebActorReminderStore(
            maximumPendingTasks: 1
        ) { _ in }
        let address = ActorAddress(
            type: ActorTypeID(high: 508, low: 509),
            identity: "reminder-capacity"
        )
        try await store.set(
            SwiftWebActorReminder(
                actorAddress: address,
                name: "first",
                fireDate: .distantFuture
            )
        )

        await #expect(throws: ActorSystemError.self) {
            try await store.set(
                SwiftWebActorReminder(
                    actorAddress: address,
                    name: "second",
                    fireDate: .distantFuture
                )
            )
        }
        await store.shutdown()
    }

    @Test
    func unregisterOwnsAnInFlightActivationExactlyOnce() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let activation = SwiftWebActorActivationProbe()
        let passivationCount = Mutex(0)
        let factory = SwiftWebActorFactory(
            SwiftWebActorHostFixtureReference.self,
            activate: { address in
                await activation.waitUntilReleasedAfterCancellation()
                return SwiftWebActorHostFixtureReference(id: address)
            },
            passivate: { _ in
                passivationCount.withLock { $0 += 1 }
            }
        )
        try await host.register(factory)
        let invocation = Self.fixtureInvocation(identity: "unregister-activation")

        let invocationTask = Task {
            try await host.intercept(
                invocation,
                context: Self.context(sequence: 3),
                execution: ActorInvocationExecution {
                    ActorInvocationResult()
                }
            )
        }
        await eventuallySwiftWebActorHost {
            await activation.didStart
        }
        let unregisterTask = Task {
            try await host.unregister(
                actorType: SwiftWebActorHostFixtureReference.actorTypeDescriptor.id
            )
        }
        await eventuallySwiftWebActorHost {
            await activation.didObserveCancellation
        }
        await activation.release()

        _ = try await unregisterTask.value
        await #expect(throws: ActorSystemError.self) {
            _ = try await invocationTask.value
        }
        #expect(passivationCount.withLock { $0 } == 1)
        #expect(
            await !host.claimsLocalInvocation(for: invocation.recipient)
        )
        await #expect(throws: ActorSystemError.self) {
            _ = try await host.intercept(
                invocation,
                context: Self.context(sequence: 4),
                execution: ActorInvocationExecution {
                    ActorInvocationResult()
                }
            )
        }

        try await host.shutdown()
    }

    @Test
    func activationCallbackCannotWaitForItsOwnHostTermination() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let hostReference = Mutex<SwiftWebActorHost?>(host)
        let requestedTermination = Mutex<ActorSystemTermination?>(nil)
        let reentrantWaitError = Mutex<ActorSystemTerminationError?>(nil)
        let passivationCount = Mutex(0)
        let factory = SwiftWebActorFactory(
            SwiftWebActorHostFixtureReference.self,
            activate: { address in
                guard let host = hostReference.withLock({ $0 }) else {
                    throw ActorSystemError.activationFailed
                }
                let termination = await host.requestShutdown()
                requestedTermination.withLock { $0 = termination }
                do {
                    try await termination.wait()
                    Issue.record("Expected an activation-owned termination wait to fail")
                } catch let error as ActorSystemTerminationError {
                    reentrantWaitError.withLock { $0 = error }
                }
                return SwiftWebActorHostFixtureReference(id: address)
            },
            passivate: { _ in
                passivationCount.withLock { $0 += 1 }
            }
        )
        try await host.register(factory)

        await #expect(throws: ActorSystemError.self) {
            _ = try await host.intercept(
                Self.fixtureInvocation(identity: "activation-shutdown-requester"),
                context: Self.context(sequence: 10),
                execution: ActorInvocationExecution { ActorInvocationResult() }
            )
        }

        #expect(reentrantWaitError.withLock { $0 } == .reentrantWait)
        let termination = try #require(requestedTermination.withLock { $0 })
        try await termination.wait()
        #expect(passivationCount.withLock { $0 } == 1)
        hostReference.withLock { $0 = nil }
    }

    @Test
    func shutdownAndExplicitPassivationShareOneOwnerTask() async throws {
        let policy = SwiftWebBlockingPassivationPolicy()
        let host = SwiftWebActorHost(
            policy: policy,
            authorization: .allowAll
        )
        let passivationCount = Mutex(0)
        let factory = SwiftWebActorFactory(
            SwiftWebActorHostFixtureReference.self,
            activate: { address in
                SwiftWebActorHostFixtureReference(id: address)
            },
            passivate: { _ in
                passivationCount.withLock { $0 += 1 }
            }
        )
        try await host.register(factory)
        let invocation = Self.fixtureInvocation(identity: "shared-passivation")
        _ = try await host.intercept(
            invocation,
            context: Self.context(sequence: 5),
            execution: ActorInvocationExecution {
                ActorInvocationResult()
            }
        )

        let passivationTask = Task {
            try await host.passivate(address: invocation.recipient)
        }
        await eventuallySwiftWebActorHost {
            await policy.didStartPassivation
        }
        let shutdownTask = Task {
            try await host.shutdown()
        }
        await Task.yield()
        await policy.releasePassivation()

        _ = try await passivationTask.value
        try await shutdownTask.value
        #expect(passivationCount.withLock { $0 } == 1)
    }

    @Test
    func passivationCallbackCannotWaitForItsOwnHostTermination() async throws {
        let policy = SwiftWebBlockingPassivationPolicy()
        let host = SwiftWebActorHost(
            policy: policy,
            authorization: .allowAll
        )
        await policy.requestShutdownDuringPassivation(of: host)
        let factory = SwiftWebActorFactory(
            SwiftWebActorHostFixtureReference.self,
            activate: { address in
                SwiftWebActorHostFixtureReference(id: address)
            },
            passivate: { _ in }
        )
        try await host.register(factory)
        let invocation = Self.fixtureInvocation(identity: "passivation-shutdown-requester")
        _ = try await host.intercept(
            invocation,
            context: Self.context(sequence: 9),
            execution: ActorInvocationExecution { ActorInvocationResult() }
        )

        let passivation = Task {
            try await host.passivate(address: invocation.recipient)
        }
        await eventuallySwiftWebActorHost {
            await policy.shutdownRequested
        }
        await eventuallySwiftWebActorHost {
            await policy.reentrantWaitError == .reentrantWait
        }
        #expect(await policy.reentrantWaitError == .reentrantWait)
        await policy.releasePassivation()
        try await passivation.value

        let termination = try #require(await policy.requestedTermination)
        try await termination.wait()
    }

    @Test
    func invocationCanRequestHostShutdownWithoutWaitingForItsOwnDrain() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let address = ActorAddress(
            type: ActorTypeID(high: 514, low: 515),
            identity: "shutdown-requester"
        )
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(516),
            schemaFingerprint: ActorSchemaFingerprint(high: 517, low: 518),
            payload: ActorByteBuffer()
        )
        let requestedTermination = Mutex<ActorSystemTermination?>(nil)
        try await host.registerBound(address: address)

        _ = try await host.intercept(
            invocation,
            context: Self.context(sequence: 6),
            execution: ActorInvocationExecution {
                let termination = await host.requestShutdown()
                requestedTermination.withLock { $0 = termination }
                do {
                    try await termination.wait()
                    Issue.record("Expected an invocation-owned termination wait to fail")
                } catch let error as ActorSystemTerminationError {
                    #expect(error == .reentrantWait)
                }
                return ActorInvocationResult()
            }
        )

        // An external owner still observes completion only after finalization.
        let termination = try #require(requestedTermination.withLock { $0 })
        try await termination.wait()
        await #expect(throws: SwiftWebActorHostError.self) {
            _ = try await host.intercept(
                invocation,
                context: Self.context(sequence: 7),
                execution: ActorInvocationExecution {
                    ActorInvocationResult()
                }
            )
        }
    }

    @Test
    func reminderDeliveryCanRequestHostShutdownWithoutJoiningItsOwnStoreTask() async throws {
        let hostReference = Mutex<SwiftWebActorHost?>(nil)
        let requestedTermination = Mutex<ActorSystemTermination?>(nil)
        let deliveryCompleted = Mutex(false)
        let address = ActorAddress(
            type: ActorTypeID(high: 519, low: 520),
            identity: "reminder-shutdown-requester"
        )
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(521),
            schemaFingerprint: ActorSchemaFingerprint(high: 522, low: 523),
            payload: ActorByteBuffer()
        )
        let store = try InProcessSwiftWebActorReminderStore { _ in
            guard let host = hostReference.withLock({ $0 }) else {
                return
            }
            do {
                _ = try await host.intercept(
                    invocation,
                    context: Self.context(sequence: 8),
                    execution: ActorInvocationExecution {
                        let termination = await host.requestShutdown()
                        requestedTermination.withLock { $0 = termination }
                        do {
                            try await termination.wait()
                            Issue.record("Expected a reminder-owned termination wait to fail")
                        } catch let error as ActorSystemTerminationError {
                            #expect(error == .reentrantWait)
                        }
                        return ActorInvocationResult()
                    }
                )
                deliveryCompleted.withLock { $0 = true }
            } catch {
                Issue.record("Unexpected reminder delivery shutdown error: \(error)")
            }
        }
        let host = SwiftWebActorHost(
            authorization: .allowAll,
            reminderStore: store
        )
        hostReference.withLock { $0 = host }
        try await host.registerBound(address: address)

        try await host.reminders(for: address).set("shutdown", in: .seconds(0))
        await eventuallySwiftWebActorHost {
            deliveryCompleted.withLock { $0 }
        }

        let termination = try #require(requestedTermination.withLock { $0 })
        try await termination.wait()
        hostReference.withLock { $0 = nil }
        #expect(deliveryCompleted.withLock { $0 })
    }

    private static func context(sequence: UInt64) -> ActorInvocationContext {
        ActorInvocationContext(
            callID: ActorCallID(
                session: ActorSessionID(500),
                sequence: sequence
            ),
            origin: .local,
            remainingTimeout: nil
        )
    }

    private static func fixtureInvocation(identity: String) -> ActorInvocation {
        ActorInvocation(
            recipient: ActorAddress(
                type: SwiftWebActorHostFixtureReference.actorTypeDescriptor.id,
                identity: identity
            ),
            method: ActorMethodID(510),
            schemaFingerprint: SwiftWebActorHostFixtureReference
                .actorTypeDescriptor.schemaFingerprint,
            payload: ActorByteBuffer()
        )
    }
}

private struct SwiftWebActorHostFixtureReference: ActorSystemReference {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 510, low: 511),
        schemaFingerprint: ActorSchemaFingerprint(high: 512, low: 513),
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

private struct SwiftWebPersistentHostFixtureReference: ActorSystemReference {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 531, low: 532),
        schemaFingerprint: ActorSchemaFingerprint(high: 533, low: 534),
        methods: []
    )

    let id: ActorAddress
    let actorSystem: Void = ()
    @ActorStorage("value") private var value = 1

    static func resolve(
        id: ActorAddress,
        using actorSystem: Void
    ) throws -> Self {
        _ = actorSystem
        return Self(id: id)
    }
}

private enum SwiftWebHostPersistenceFixtureError: Error, Equatable {
    case saveFailed
}

private final class SwiftWebFailingShutdownPersistentStore: WebActorPersistentStore {
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
                throw SwiftWebHostPersistenceFixtureError.saveFailed
            }
            state.values[actorID] = values
        }
    }
}

private actor SwiftWebActorActivationProbe {
    private(set) var didStart = false
    private(set) var didObserveCancellation = false
    private var isReleased = false

    func waitUntilReleasedAfterCancellation() async {
        didStart = true
        while !isReleased {
            if Task.isCancelled {
                didObserveCancellation = true
            }
            await Task.yield()
        }
    }

    func release() {
        isReleased = true
    }
}

private actor SwiftWebBlockingPassivationPolicy: SwiftWebActorHostPolicy {
    private(set) var didStartPassivation = false
    private var isPassivationReleased = false
    private var shutdownHost: SwiftWebActorHost?
    private(set) var requestedTermination: ActorSystemTermination?
    private(set) var reentrantWaitError: ActorSystemTerminationError?

    var shutdownRequested: Bool {
        requestedTermination != nil
    }

    func authorize(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        isActive: Bool
    ) async throws {
        _ = (invocation, context, isActive)
    }

    func willActivate(address: ActorAddress) async throws {
        _ = address
    }

    func didActivate(address: ActorAddress) async throws {
        _ = address
    }

    func activationFailed(address: ActorAddress, error: any Error) async {
        _ = (address, error)
    }

    func willInvoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws {
        _ = (invocation, context)
    }

    func didInvoke(
        _ invocation: ActorInvocation,
        result: ActorInvocationResult,
        context: ActorInvocationContext
    ) async throws {
        _ = (invocation, result, context)
    }

    func invocationFailed(
        _ invocation: ActorInvocation,
        error: any Error,
        context: ActorInvocationContext
    ) async {
        _ = (invocation, error, context)
    }

    func willPassivate(address: ActorAddress) async throws {
        _ = address
        didStartPassivation = true
        if let shutdownHost {
            let termination = await shutdownHost.requestShutdown()
            requestedTermination = termination
            do {
                try await termination.wait()
                Issue.record("Expected a passivation-owned termination wait to fail")
            } catch let error as ActorSystemTerminationError {
                reentrantWaitError = error
            }
        }
        while !isPassivationReleased {
            await Task.yield()
        }
    }

    func passivationFailed(address: ActorAddress, error: any Error) async {
        _ = (address, error)
    }

    func shutdown() async {}

    func releasePassivation() {
        isPassivationReleased = true
    }

    func requestShutdownDuringPassivation(of host: SwiftWebActorHost) {
        shutdownHost = host
    }
}

private actor SwiftWebReminderDeliveryProbe {
    private(set) var deliveryCount = 0

    func deliver(_ reminder: SwiftWebActorReminder) {
        _ = reminder
        deliveryCount += 1
    }
}

private actor SwiftWebActorGateProbe {
    private var firstContinuation: CheckedContinuation<Void, Never>?
    private(set) var firstExecutionStarted = false
    private(set) var executionCount = 0

    func executeFirst() async -> ActorInvocationResult {
        executionCount += 1
        firstExecutionStarted = true
        await withCheckedContinuation { continuation in
            firstContinuation = continuation
        }
        return ActorInvocationResult()
    }

    func executeSecond() -> ActorInvocationResult {
        executionCount += 1
        return ActorInvocationResult()
    }

    func releaseFirst() {
        firstContinuation?.resume()
        firstContinuation = nil
    }
}

private func eventuallySwiftWebActorHost(
    _ condition: @escaping @Sendable () async -> Bool
) async {
    for _ in 0..<10_000 {
        if await condition() {
            return
        }
        await Task.yield()
    }
    Issue.record("Condition did not become true")
}
