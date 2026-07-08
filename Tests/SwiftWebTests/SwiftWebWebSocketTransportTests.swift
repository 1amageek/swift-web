import Distributed
import Foundation
import Synchronization
import Testing

@testable import SwiftWeb
@testable import SwiftWebActors
@testable import SwiftWebCore

@Suite
struct WebSocketActorTransportTests {
    @Test
    func clientCallsAgentAndAgentPushesToObserverOverOneDuplexChannel() async throws {
        // Server side: agent family + session router for pushes.
        let serverSystem = WebActorSystem()
        let router = WebSocketSessionRouter()
        serverSystem.setTransport(router)
        serverSystem.registerActivator(for: WSAgent.self) {
            _ = WSAgent(actorSystem: serverSystem)
        }

        // Client side: local observer.
        let clientSystem = WebActorSystem()
        let observer = WSObserver(actorSystem: clientSystem)

        // One in-memory duplex "socket": each side's frames feed the other.
        let clientEnd = TransportBox()
        let serverEnd = TransportBox()
        let clientTransport = WebSocketActorTransport(senderID: observer.id) { text in
            serverEnd.take().receive(text)
        }
        let serverTransport = WebSocketActorTransport(inboundSenderPolicy: .bind(observer.id)) { text in
            clientEnd.take().receive(text)
        }
        clientEnd.fill(clientTransport)
        serverEnd.fill(serverTransport)

        clientTransport.bind(clientSystem)
        clientSystem.setTransport(clientTransport)
        serverTransport.bind(serverSystem)
        serverTransport.onInboundSender { peerID, transport in
            router.register(peerID, transport: transport)
        }

        // Client → agent (unary), agent → observer (typed pushes), both over
        // the same channel, correlated by callID.
        let agentID = WebActorSystem.actorID(for: WSAgent.self, named: "session-1")
        let agent = try $WSAgentProtocol.resolve(id: agentID, using: clientSystem)
        let pushed = try await agent.start(observerID: observer.id, count: 3)

        #expect(pushed == 3)
        #expect(try await observer.received() == ["token-1", "token-2", "token-3"])
    }

    @Test
    func closingTheSocketFailsInFlightCalls() async throws {
        let transport = WebSocketActorTransport { _ in
            // Never delivered: the peer is gone.
        }
        let clientSystem = WebActorSystem(transport: transport)
        let agent = try $WSAgentProtocol.resolve(
            id: WebActorSystem.actorID(for: WSAgent.self, named: "gone"),
            using: clientSystem
        )

        let call = Task {
            try await agent.start(observerID: "nobody", count: 1)
        }
        try await Task.sleep(for: .milliseconds(20))
        transport.closed()

        let result = await call.result
        #expect(throws: (any Error).self) {
            _ = try result.get()
        }
    }

    @Test
    func boundWebSocketSenderRejectsSpoofedSenderID() async throws {
        let frames = SentFrameStore()
        let transport = WebSocketActorTransport(inboundSenderPolicy: .bind("observer-1")) { text in
            frames.append(text)
        }
        transport.onInboundSender { _, _ in
            Issue.record("Spoofed sender must not be registered for push routing")
        }
        let invocation = InvocationEnvelope(
            callID: "spoof-call",
            recipientID: "agent-1",
            senderID: "attacker-observer",
            target: "noop",
            arguments: []
        )

        transport.receive(String(decoding: try JSONEncoder().encode(Envelope.invocation(invocation)), as: UTF8.self))
        try await Task.sleep(for: .milliseconds(20))

        guard let text = frames.first() else {
            Issue.record("Expected a rejection response frame")
            return
        }
        guard case .response(let response) = try JSONDecoder().decode(Envelope.self, from: Data(text.utf8)) else {
            Issue.record("Expected a response envelope")
            return
        }
        guard case .failure(let error) = response.result else {
            Issue.record("Expected a failed response")
            return
        }
        #expect(String(describing: error).contains("senderID is not bound"))
    }
}

private final class TransportBox: Sendable {
    private let value = Mutex<WebSocketActorTransport?>(nil)

    func fill(_ transport: WebSocketActorTransport) {
        value.withLock { $0 = transport }
    }

    func take() -> WebSocketActorTransport {
        guard let transport = value.withLock({ $0 }) else {
            preconditionFailure("transport used before wiring completed")
        }
        return transport
    }
}

private final class SentFrameStore: Sendable {
    private let frames = Mutex<[String]>([])

    func append(_ frame: String) {
        frames.withLock { $0.append(frame) }
    }

    func first() -> String? {
        frames.withLock { $0.first }
    }
}

// MARK: - Fixtures

@Resolvable
protocol WSAgentProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func start(observerID: String, count: Int) async throws -> Int
}

@Resolvable
protocol WSObserverProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func token(_ text: String) async throws
}

@ResolvableActor(WSAgentProtocol.self)
private distributed actor WSAgent: WSAgentProtocol {
    typealias ActorSystem = WebActorSystem

    distributed func start(observerID: String, count: Int) async throws -> Int {
        let observer = try $WSObserverProtocol.resolve(id: observerID, using: actorSystem)
        for index in 1...count {
            try await observer.token("token-\(index)")
        }
        return count
    }
}

@ResolvableActor(WSObserverProtocol.self)
private distributed actor WSObserver: WSObserverProtocol {
    typealias ActorSystem = WebActorSystem

    private var tokens: [String] = []

    distributed func token(_ text: String) {
        tokens.append(text)
    }

    distributed func received() -> [String] {
        tokens
    }
}
