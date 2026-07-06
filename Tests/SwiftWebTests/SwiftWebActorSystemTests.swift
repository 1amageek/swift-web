import Distributed
import Foundation
@testable import SwiftWeb
@testable import SwiftWebActors
@testable import SwiftWebCore
import Testing

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
    func actorMacroResolvesScopedResolvableProtocol() async throws {
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

