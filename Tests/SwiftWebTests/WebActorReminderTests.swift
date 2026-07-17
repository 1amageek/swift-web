#if SWIFTWEB_ACTORS
import Distributed
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
    typealias ActorSystem = WebActorSystem

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
        let system = WebActorSystem()
        let log = ReminderLog()
        let store = InProcessActorReminderStore { reminder in
            do {
                try await system.deliverReminder(reminder)
            } catch {
                log.record("delivery-error: \(error)")
            }
        }
        system.setReminderStore(store)
        system.registerActivator(for: ReminderProbe.self) {
            _ = ReminderProbe(actorSystem: system, log: log)
        }

        let actorID = WebActorSystem.actorID(for: ReminderProbe.self, named: "probe")
        try await system.reminders(for: actorID).set("digest", in: .seconds(0))

        for _ in 0..<100 {
            if !log.recorded.isEmpty {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(log.recorded == ["digest"])
        #expect(try await store.pending(actorID: actorID).isEmpty)
    }

    @Test func remindersWithoutStoreThrow() async {
        let system = WebActorSystem()
        let actorID = WebActorSystem.actorID(for: ReminderProbe.self, named: "p2")
        await #expect(throws: WebActorReminderError.storeNotInstalled(actorID: actorID)) {
            try await system.reminders(for: actorID).set("x", in: .seconds(1))
        }
    }

    @Test func cancelRemovesPendingReminder() async throws {
        let store = InProcessActorReminderStore { _ in }
        let reminder = WebActorReminder(actorID: "c:1", name: "n", fireDate: Date().addingTimeInterval(60))
        try await store.set(reminder)
        #expect(try await store.pending(actorID: "c:1") == [reminder])
        try await store.cancel(actorID: "c:1", name: "n")
        #expect(try await store.pending(actorID: "c:1").isEmpty)
    }
}
#endif
