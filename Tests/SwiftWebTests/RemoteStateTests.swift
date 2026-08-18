#if SWIFTWEB_ACTORS
import ActorSystemCore
import Distributed
#if SWIFTWEB_LEGACY_ACTORS
import Foundation
import Synchronization
import Testing
@testable import SwiftWebActors

private final class RecordingStatePublisher: WebActorStatePublisher {
    private let changes = Mutex<[RemoteStateChange]>([])

    func publish(_ change: RemoteStateChange) async {
        changes.withLock { $0.append(change) }
    }

    var recorded: [RemoteStateChange] {
        changes.withLock { $0 }
    }
}

private distributed actor StreamingProbe: WebActorRemindable {
    typealias ActorSystem = LegacyWebActorSystem

    @RemoteState("progress") private var progress = 0

    init(actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
    }

    func reminder(_ name: String) async throws {
        progress = 42
    }
}

@Suite struct RemoteStateTests {
    @Test func activatedActorPublishesStateChanges() async throws {
        let system = LegacyWebActorSystem()
        let publisher = RecordingStatePublisher()
        system.setStatePublisher(publisher)
        system.registerActivator(for: StreamingProbe.self) {
            _ = StreamingProbe(actorSystem: system)
        }

        let actorID = LegacyWebActorSystem.actorID(for: StreamingProbe.self, named: "s1")
        try await system.deliverReminder(
            WebActorReminder(actorID: actorID, name: "tick", fireDate: Date())
        )

        for _ in 0..<100 {
            if !publisher.recorded.isEmpty {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        let change = try #require(publisher.recorded.first)
        #expect(change.actorID == actorID)
        #expect(change.key == "progress")
        #expect(try JSONDecoder().decode(Int.self, from: change.value) == 42)
    }

    @Test func unboundRemoteStateKeepsValueLocally() {
        @RemoteState("draft") var draft = "a"
        draft = "b"
        #expect(draft == "b")
    }

    @Test func unbindDrainsPublicationBeforeFinishing() async {
        let publisher = BlockingSwiftWebStatePublisher()
        let address = ActorAddress(
            type: ActorTypeID(high: 601, low: 602),
            identity: "remote-state-drain"
        )
        let box = RemoteStateBox(key: "value", value: 0)
        box.bind(actorAddress: address, publisher: publisher)
        box.update(1)
        await publisher.waitUntilPublishing()

        let completion = RemoteStateUnbindCompletion()
        let unbind = Task {
            await box.unbind()
            await completion.markCompleted()
        }
        await Task.yield()
        #expect(await publisher.eventNames == ["publish-start"])
        #expect(await completion.isCompleted == false)

        await publisher.releasePublication()
        await unbind.value
        await publisher.finish(actorAddress: address)

        #expect(
            await publisher.eventNames
                == ["publish-start", "publish-end", "finish"]
        )
    }
}

private actor BlockingSwiftWebStatePublisher: SwiftWebActorStatePublisher {
    private var events: [String] = []
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    var eventNames: [String] {
        events
    }

    func publish(_ change: SwiftWebRemoteStateChange) async {
        _ = change
        events.append("publish-start")
        let waiters = startedWaiters
        startedWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        events.append("publish-end")
    }

    func finish(actorAddress: ActorAddress) async {
        _ = actorAddress
        events.append("finish")
    }

    func waitUntilPublishing() async {
        if events.contains("publish-start") {
            return
        }
        await withCheckedContinuation { continuation in
            startedWaiters.append(continuation)
        }
    }

    func releasePublication() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor RemoteStateUnbindCompletion {
    private(set) var isCompleted = false

    func markCompleted() {
        isCompleted = true
    }
}
#endif
#endif
