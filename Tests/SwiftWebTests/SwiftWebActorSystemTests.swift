import Distributed
import Foundation
import HTTPTypes
import NIOCore
@testable import SwiftWeb
@testable import SwiftWebCore
import Testing
import Vapor
import VaporTesting

@Suite
struct SwiftWebActorSystemTests {
    @Test
    func resolvableProtocolCallsRemoteActorThroughTransport() async throws {
        let serverSystem = WebActorSystem()
        let service = TestCounterService(actorSystem: serverSystem)
        let clientSystem = WebActorSystem(transport: LoopbackWebActorTransport(system: serverSystem))

        let remote = try $TestCounterServiceProtocol.resolve(id: service.id, using: clientSystem)
        let value = try await remote.increment(by: 3)

        #expect(value == 3)
        #expect(try await service.currentValue() == 3)
    }

    @Test
    func vaporGatewayExecutesInvocationEnvelope() async throws {
        let application = try await Application()
        var configuration = SecurityConfiguration.defaults
        configuration.csrf = .disabled
        application.securityConfiguration = configuration
        WebActorGateway.register(on: application)
        let service = TestCounterService(actorSystem: .shared)
        let captureStore = CapturedEnvelopeStore()
        let clientSystem = WebActorSystem(
            transport: CapturingWebActorTransport(store: captureStore)
        )
        let remote = try $TestCounterServiceProtocol.resolve(id: service.id, using: clientSystem)

        do {
            _ = try await remote.increment(by: 4)
            Issue.record("Capturing transport should throw after recording the envelope")
        } catch {}

        let envelope = try await captureStore.requireEnvelope()
        var headers: HTTPFields = [:]
        headers[.contentType] = "application/json"
        let response = try await application.testing().sendRequest(
            .post,
            WebActorGateway.path,
            hostname: "example.com",
            headers: headers,
            body: ByteBufferAllocator().buffer(data: try JSONEncoder().encode(envelope))
        )
        try await application.shutdown()
        WebActorSystem.shared.shutdown()

        #expect(response.status == .ok)
        let responseEnvelope = try JSONDecoder().decode(
            ResponseEnvelope.self,
            from: Data(buffer: response.body)
        )
        guard case .success(let data) = responseEnvelope.result else {
            Issue.record("Gateway should return a successful invocation result")
            return
        }
        let value = try JSONDecoder().decode(Int.self, from: data)
        #expect(value == 4)
    }

    @Test
    func vaporGatewayRequiresCSRFWhenEnabled() async throws {
        let application = try await Application()
        application.securityConfiguration = .defaults
        WebActorGateway.register(on: application)

        var headers: HTTPFields = [:]
        headers[.contentType] = "application/json"
        let response = try await application.testing().sendRequest(
            .post,
            WebActorGateway.path,
            hostname: "example.com",
            headers: headers,
            body: ByteBufferAllocator().buffer(string: "{}")
        )
        try await application.shutdown()

        #expect(response.status == .forbidden)
    }
}

@Resolvable
protocol TestCounterServiceProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func increment(by amount: Int) async throws -> Int
    distributed func currentValue() async throws -> Int
}

private distributed actor TestCounterService: TestCounterServiceProtocol {
    typealias ActorSystem = WebActorSystem

    private var value = 0

    distributed func increment(by amount: Int) async throws -> Int {
        value += amount
        return value
    }

    distributed func currentValue() async throws -> Int {
        value
    }
}

private struct LoopbackWebActorTransport: WebActorTransport {
    let system: WebActorSystem

    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        try await system.invoke(envelope: envelope)
    }
}

private struct CapturingWebActorTransport: WebActorTransport {
    let store: CapturedEnvelopeStore

    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        await store.store(envelope)
        throw RuntimeError.transportFailed("captured")
    }
}

private actor CapturedEnvelopeStore {
    private var envelope: InvocationEnvelope?

    func store(_ envelope: InvocationEnvelope) {
        self.envelope = envelope
    }

    func requireEnvelope() throws -> InvocationEnvelope {
        guard let envelope else {
            throw CapturedEnvelopeError.missingEnvelope
        }
        return envelope
    }
}

private enum CapturedEnvelopeError: Error {
    case missingEnvelope
}
