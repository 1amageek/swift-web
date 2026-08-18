#if SWIFTWEB_ACTORS
import Distributed
#if SWIFTWEB_LEGACY_ACTORS
import ActorSystemCore
import Foundation
import Synchronization
import Testing
@testable import SwiftWebActors

private final class ReminderLog: Sendable {
    private let names = Mutex<[String]>([])

    func record(_ name: String) {
        names.withLock { $0.append(name) }
    }

    var recorded: [String] {
        names.withLock { $0 }
    }
}

private distributed actor ReminderProbe: WebActorRemindable {
    typealias ActorSystem = LegacyWebActorSystem

    private let log: ReminderLog

    init(actorSystem: ActorSystem, log: ReminderLog) {
        self.actorSystem = actorSystem
        self.log = log
    }

    func reminder(_ name: String) async throws {
        log.record(name)
    }
}

@Suite struct WebActorReminderTests {
    @Test func firedReminderActivatesActorAndInvokesHandler() async throws {
        let system = LegacyWebActorSystem()
        let log = ReminderLog()
        let store = try InProcessActorReminderStore { reminder in
            do {
                try await system.deliverReminder(reminder)
            } catch {
                log.record("delivery-error: \(error)")
            }
        }
        try await system.setReminderStore(store)
        system.registerActivator(for: ReminderProbe.self) {
            _ = ReminderProbe(actorSystem: system, log: log)
        }

        let actorID = LegacyWebActorSystem.actorID(for: ReminderProbe.self, named: "probe")
        try await system.reminders(for: actorID).set("digest", in: .seconds(0))

        for _ in 0..<100 {
            if !log.recorded.isEmpty {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(log.recorded == ["digest"])
        #expect(try await store.pending(actorID: actorID).isEmpty)
        try await system.shutdown()
    }

    @Test func remindersWithoutStoreThrow() async throws {
        let system = LegacyWebActorSystem()
        let actorID = LegacyWebActorSystem.actorID(for: ReminderProbe.self, named: "p2")
        await #expect(throws: WebActorReminderError.storeNotInstalled(actorID: actorID)) {
            try await system.reminders(for: actorID).set("x", in: .seconds(1))
        }
        try await system.shutdown()
    }

    @Test func cancelRemovesPendingReminder() async throws {
        let store = try InProcessActorReminderStore { _ in }
        let reminder = WebActorReminder(actorID: "c:1", name: "n", fireDate: Date().addingTimeInterval(60))
        try await store.set(reminder)
        #expect(try await store.pending(actorID: "c:1") == [reminder])
        try await store.cancel(actorID: "c:1", name: "n")
        #expect(try await store.pending(actorID: "c:1").isEmpty)
        try await store.shutdown()
    }

    @Test
    func reminderStoreRetainsTasksWithinItsConfiguredBoundUntilCompletion() async throws {
        let store = try InProcessActorReminderStore(maximumPendingTasks: 1) { _ in }
        try await store.set(
            WebActorReminder(
                actorID: "fixture:one",
                name: "first",
                fireDate: .distantFuture
            )
        )

        await #expect(throws: ActorSystemError.self) {
            try await store.set(
                WebActorReminder(
                    actorID: "fixture:two",
                    name: "second",
                    fireDate: .distantFuture
                )
            )
        }

        try await store.shutdown()
    }

    @Test
    func reminderDeliveryCannotWaitForItsOwningLegacySystemShutdown() async throws {
        let system = LegacyWebActorSystem()
        let requestedTermination = Mutex<ActorSystemTermination?>(nil)
        let waitError = Mutex<ActorSystemTerminationError?>(nil)
        let envelope = InvocationEnvelope(
            callID: "reminder-owned-shutdown",
            recipientID: "fixture:missing",
            target: "noop",
            arguments: []
        )
        let authorization = WebActorAuthorization { _ in
            let termination = system.requestShutdown()
            requestedTermination.withLock { $0 = termination }
            do {
                try await termination.wait()
                Issue.record("Expected reminder-owned shutdown wait to fail")
            } catch let error as ActorSystemTerminationError {
                waitError.withLock { $0 = error }
            } catch {
                Issue.record("Unexpected reminder shutdown error: \(error)")
            }
            return .deny("fixture completed")
        }
        let store = try InProcessActorReminderStore { _ in
            do {
                _ = try await system.invoke(
                    envelope: envelope,
                    context: .trusted,
                    authorization: authorization
                )
                Issue.record("Expected fixture authorization to deny the invocation")
            } catch is WebActorAuthorizationError {
                return
            } catch {
                Issue.record("Unexpected reminder delivery error: \(error)")
            }
        }
        try await system.setReminderStore(store)
        try await store.set(
            WebActorReminder(
                actorID: "fixture:shutdown",
                name: "shutdown",
                fireDate: Date()
            )
        )
        for _ in 0..<10_000 {
            if waitError.withLock({ $0 }) != nil {
                break
            }
            await Task.yield()
        }

        #expect(waitError.withLock { $0 } == .reentrantWait)
        let termination = try #require(requestedTermination.withLock { $0 })
        try await termination.wait()
        #expect(termination.isTerminated)
        await #expect(throws: ActorSystemError.self) {
            _ = try await store.pending(actorID: "fixture:shutdown")
        }
    }
}
#endif
#endif
