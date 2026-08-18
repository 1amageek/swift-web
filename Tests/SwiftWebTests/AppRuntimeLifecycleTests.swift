@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
import Synchronization
import Testing
@_spi(Hosting) @testable import SwiftWebCore

@Suite
struct AppRuntimeLifecycleTests {
    @Test(.timeLimit(.minutes(1)))
    func concurrentExternalStartsShareOneOwnedStartTask() async throws {
        let gate = AppRuntimeLifecycleGate()
        let lifecycle = ActorSystemLifecycleCoordinator(
            start: {
                try await gate.start()
            },
            requestShutdown: {
                ActorSystemTermination(operation: {
                    await gate.shutdown()
                })
            }
        )
        let first = Task {
            try await lifecycle.start()
        }
        await gate.waitUntilStartBegins()
        let second = Task {
            try await lifecycle.start()
        }

        await gate.finishStart()
        try await first.value
        try await second.value
        #expect(await gate.startCount == 1)

        let termination = await lifecycle.requestShutdown()
        try await termination.wait()
    }

    @Test(.timeLimit(.minutes(1)))
    func ownedStartRejectsRecursiveStartAndTerminationWaitWithoutStoppingCleanup() async throws {
        let probe = AppRuntimeLifecycleReentrancyProbe()
        let lifecycle = ActorSystemLifecycleCoordinator(
            start: {
                try await probe.run()
            },
            requestShutdown: {
                ActorSystemTermination()
            }
        )
        probe.install(lifecycle)

        do {
            try await lifecycle.start()
            Issue.record("Expected shutdown requested by start to interrupt startup")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected lifecycle start error: \(error)")
        }

        #expect(probe.recursiveStartError == .alreadyStarted)
        #expect(probe.reentrantWaitError == .reentrantWait)
        let termination = try #require(probe.requestedTermination)
        try await termination.wait()
        #expect(termination.isTerminated)
    }

    @Test(.timeLimit(.minutes(1)))
    func shutdownUnblocksAndJoinsAnInProgressStart() async throws {
        let gate = AppRuntimeLifecycleGate()
        let lifecycle = ActorSystemLifecycleCoordinator(
            start: {
                try await gate.start()
            },
            requestShutdown: {
                ActorSystemTermination(operation: {
                    await gate.shutdown()
                })
            }
        )
        let startTask = Task {
            try await lifecycle.start()
        }
        await gate.waitUntilStartBegins()

        let termination = await lifecycle.requestShutdown()
        try await termination.wait()

        #expect(await gate.shutdownWasCalled)
        do {
            try await startTask.value
            Issue.record("Expected the interrupted start to fail")
        } catch {
            let actorSystemError = error as? ActorSystemError
            #expect(error is CancellationError || actorSystemError == .shuttingDown)
        }
    }
}

private actor AppRuntimeLifecycleGate {
    private var startInvocations = 0
    private var startBegan = false
    private var shutdownCalled = false
    private var startContinuation: CheckedContinuation<Void, any Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    var shutdownWasCalled: Bool {
        shutdownCalled
    }

    var startCount: Int {
        startInvocations
    }

    func start() async throws {
        startInvocations += 1
        startBegan = true
        let waiters = startWaiters
        startWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
        try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitUntilStartBegins() async {
        guard !startBegan else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func shutdown() {
        shutdownCalled = true
        let continuation = startContinuation
        startContinuation = nil
        continuation?.resume(throwing: CancellationError())
    }

    func finishStart() {
        let continuation = startContinuation
        startContinuation = nil
        continuation?.resume()
    }
}

private final class AppRuntimeLifecycleReentrancyProbe: Sendable {
    private struct State: Sendable {
        var lifecycle: ActorSystemLifecycleCoordinator?
        var recursiveStartError: ActorSystemErrorCode?
        var requestedTermination: ActorSystemTermination?
        var reentrantWaitError: ActorSystemTerminationError?
    }

    private let state = Mutex(State())

    var recursiveStartError: ActorSystemErrorCode? {
        state.withLock { $0.recursiveStartError }
    }

    var requestedTermination: ActorSystemTermination? {
        state.withLock { $0.requestedTermination }
    }

    var reentrantWaitError: ActorSystemTerminationError? {
        state.withLock { $0.reentrantWaitError }
    }

    func install(_ lifecycle: ActorSystemLifecycleCoordinator) {
        state.withLock { $0.lifecycle = lifecycle }
    }

    func run() async throws {
        let lifecycle = try state.withLock { state -> ActorSystemLifecycleCoordinator in
            guard let lifecycle = state.lifecycle else {
                throw ActorSystemError.notStarted
            }
            return lifecycle
        }
        do {
            try await lifecycle.start()
            Issue.record("Expected an owned recursive start to be rejected")
        } catch let error as ActorSystemError {
            state.withLock { $0.recursiveStartError = error.code }
        }

        let termination = await lifecycle.requestShutdown()
        state.withLock { $0.requestedTermination = termination }
        do {
            try await termination.wait()
            Issue.record("Expected an owned termination wait to be rejected")
        } catch let error as ActorSystemTerminationError {
            state.withLock { $0.reentrantWaitError = error }
        }
    }
}
