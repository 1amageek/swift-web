#if SWIFTWEB_ACTORS
import ActorSystemCore
import ActorSystemEmbedded
import Synchronization
import Testing
@_spi(Hosting) @testable import SwiftWebActors

@Suite
struct SwiftWebActorClockBindingTests {
    @Test
    func deadlineFreeSystemLifecycleKeepsTheBindingWindowOpen() async throws {
        let binding = SwiftWebActorClockBinding()
        let target = DeadlineFreeTarget()
        let directory = ActorDirectory()
        try directory.register(target)
        let system = ActorSystemCore(
            directory: directory,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(1)
                ),
                clock: binding
            )
        )

        try await system.start()
        _ = try await system.invoke(
            ActorInvocation(
                recipient: target.address,
                method: ActorMethodID(1),
                schemaFingerprint: target.descriptor.schemaFingerprint,
                payload: ActorByteBuffer()
            )
        )
        try await system.shutdown()

        let clock = RecordingActorClock()
        try binding.install(clock)
        try await binding.sleep(for: .milliseconds(1))
        #expect(clock.sleepCount == 1)
    }

    @Test
    func repeatedInstallationIsRejected() throws {
        let binding = SwiftWebActorClockBinding()
        try binding.install(RecordingActorClock())

        #expect(
            throws: SwiftWebActorSystemConfigurationError.actorClockAlreadyInstalled
        ) {
            try binding.install(RecordingActorClock())
        }
    }

    @Test
    func firstClockUseSealsTheBindingWindow() async throws {
        let binding = SwiftWebActorClockBinding()

        #if hasFeature(Embedded)
        await #expect(throws: ActorClockUnavailable.self) {
            try await binding.sleep(for: .zero)
        }
        #else
        try await binding.sleep(for: .zero)
        #endif
        #expect(
            throws: SwiftWebActorSystemConfigurationError.actorClockInstallationTooLate
        ) {
            try binding.install(RecordingActorClock())
        }
    }

    @Test
    func concurrentInstallationAndFirstUseAreLinearizable() async {
        for iteration in 0..<16 {
            let binding = SwiftWebActorClockBinding()
            let clock = RecordingActorClock()
            let outcomes = await withTaskGroup(
                of: ConcurrentClockAttempt.self,
                returning: [ConcurrentClockAttempt].self
            ) { group in
                if iteration.isMultiple(of: 2) {
                    group.addTask {
                        do {
                            try binding.install(clock)
                            return .installationSucceeded
                        } catch SwiftWebActorSystemConfigurationError
                            .actorClockInstallationTooLate {
                            return .installationTooLate
                        } catch {
                            return .unexpectedInstallationFailure
                        }
                    }
                    group.addTask {
                        do {
                            try await binding.sleep(for: .zero)
                            return .sleepCompleted
                        } catch is ActorClockUnavailable {
                            return .sleepUnavailable
                        } catch {
                            return .unexpectedSleepFailure
                        }
                    }
                } else {
                    group.addTask {
                        do {
                            try await binding.sleep(for: .zero)
                            return .sleepCompleted
                        } catch is ActorClockUnavailable {
                            return .sleepUnavailable
                        } catch {
                            return .unexpectedSleepFailure
                        }
                    }
                    group.addTask {
                        do {
                            try binding.install(clock)
                            return .installationSucceeded
                        } catch SwiftWebActorSystemConfigurationError
                            .actorClockInstallationTooLate {
                            return .installationTooLate
                        } catch {
                            return .unexpectedInstallationFailure
                        }
                    }
                }

                var outcomes: [ConcurrentClockAttempt] = []
                for await outcome in group {
                    outcomes.append(outcome)
                }
                return outcomes
            }

            #expect(outcomes.count == 2)
            let installationSucceeded = outcomes.contains(.installationSucceeded)
            let installationTooLate = outcomes.contains(.installationTooLate)
            #expect(installationSucceeded != installationTooLate)

            if installationSucceeded {
                #expect(outcomes.contains(.sleepCompleted))
                #expect(clock.sleepCount == 1)
            } else {
                #if hasFeature(Embedded)
                #expect(
                    outcomes.contains(.sleepUnavailable)
                )
                #else
                #expect(outcomes.contains(.sleepCompleted))
                #endif
                #expect(clock.sleepCount == 0)
            }
            #expect(!outcomes.contains(.unexpectedInstallationFailure))
            #expect(!outcomes.contains(.unexpectedSleepFailure))
        }
    }

    #if hasFeature(Embedded)
    @Test
    func customSystemDoesNotUseTheSharedBinding() async throws {
        let customClock = RecordingActorClock()
        let customSystem = EmbeddedActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: SequentialActorIdentitySource(),
                clock: customClock
            )
        )

        let installed = try customSystem.installActorClock(RecordingActorClock())
        #expect(!installed)
        try await customSystem.configuration.clock.sleep(for: .zero)
        #expect(customClock.sleepCount == 1)
    }
    #endif
}

private enum ConcurrentClockAttempt: Sendable, Equatable {
    case installationSucceeded
    case installationTooLate
    case sleepCompleted
    case sleepUnavailable
    case unexpectedInstallationFailure
    case unexpectedSleepFailure
}

private final class RecordingActorClock: ActorClock, Sendable {
    private let state = Mutex(0)

    var sleepCount: Int {
        state.withLock { $0 }
    }

    func sleep(for duration: Duration) async throws {
        _ = duration
        state.withLock { $0 += 1 }
    }
}

private struct DeadlineFreeTarget: ActorInvocationTarget {
    let address = ActorAddress(
        type: ActorTypeID(high: 1, low: 1),
        identity: "deadline-free"
    )
    let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 1, low: 1),
        schemaFingerprint: ActorSchemaFingerprint(high: 1, low: 1),
        methods: [
            ActorMethodDescriptor(
                id: ActorMethodID(1),
                parameterTypeIDs: [],
                resultTypeID: nil,
                errorTypeID: nil
            ),
        ]
    )

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        _ = invocation
        _ = context
        return ActorInvocationResult()
    }
}
#endif
