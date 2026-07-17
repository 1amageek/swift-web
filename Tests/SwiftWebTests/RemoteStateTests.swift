#if SWIFTWEB_ACTORS
import Distributed
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
    typealias ActorSystem = WebActorSystem

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
        let system = WebActorSystem()
        let publisher = RecordingStatePublisher()
        system.setStatePublisher(publisher)
        system.registerActivator(for: StreamingProbe.self) {
            _ = StreamingProbe(actorSystem: system)
        }

        let actorID = WebActorSystem.actorID(for: StreamingProbe.self, named: "s1")
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
}
#endif
