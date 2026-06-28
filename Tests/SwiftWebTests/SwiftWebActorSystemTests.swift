import Distributed
import Foundation
import HTTPTypes
import NIOCore
@testable import SwiftWeb
@testable import SwiftWebActors
@testable import SwiftWebCore
@testable import SwiftWebVapor
@testable import SwiftWebVaporWebActors
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

    @Test
    func actorPropertyWrapperResolvesScopedResolvableProtocol() async throws {
        let serverSystem = WebActorSystem()
        let service = TestCounterService(actorSystem: serverSystem)
        let clientSystem = WebActorSystem(transport: LoopbackWebActorTransport(system: serverSystem))
        let contract = TestCounterService.swiftWebActorContractKey
        let scope = SwiftWebActorBindingScope(
            records: [
                SwiftWebActorBindingRecord(contract: contract, actorID: service.id),
            ],
            resolverRegistry: SwiftWebActorResolverRegistry([
                SwiftWebActorResolver(
                    contract: contract,
                    actorContract: $TestCounterServiceProtocol.self
                ),
            ]),
            actorSystem: clientSystem
        )

        let value = try await SwiftWebActorBindingContext.withValue(scope) {
            try await TestCounterComponent().increment(by: 5)
        }

        #expect(value == 5)
        #expect(try await service.currentValue() == 5)
    }

    @Test
    func actorBindingScopeResolvesEachContractWithItsOwnActorSystem() async throws {
        let counterSystem = WebActorSystem()
        let labelSystem = WebActorSystem()
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
where ActorSystem == WebActorSystem {
    distributed func increment(by amount: Int) async throws -> Int
    distributed func currentValue() async throws -> Int
}

@ResolvableActor(TestCounterServiceProtocol.self)
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

private struct TestCounterComponent: Sendable {
    @Actor private var counter: any TestCounterServiceProtocol

    func increment(by amount: Int) async throws -> Int {
        try await counter.increment(by: amount)
    }
}

@Resolvable
protocol TestLabelServiceProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func label() async throws -> String
}

@ResolvableActor(TestLabelServiceProtocol.self)
private distributed actor TestLabelService: TestLabelServiceProtocol {
    typealias ActorSystem = WebActorSystem

    private let value: String

    init(value: String, actorSystem: WebActorSystem) {
        self.value = value
        self.actorSystem = actorSystem
    }

    distributed func label() async throws -> String {
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
