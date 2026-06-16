import Distributed
@testable import SwiftWeb
import Testing
import Vapor

@Suite
struct SwiftWebPageOwnedServicesTests {
    @Test
    func registersPageOwnedServerActionActors() async throws {
        try await withApplication { application in
            let service = PageOwnedCounterService(actorSystem: .shared)

            try await PageOwnedServices.register(service, on: application)

            let action = try application.swiftWebServerActions.action(
                actorName: String(reflecting: PageOwnedCounterService.self),
                methodName: "increment",
                metadata: ActionRequestMetadata(
                    actorID: service.id,
                    actionName: "increment",
                    targetIdentifier: "increment(_:context:)"
                )
            )
            #expect(action.actorID == service.id)
            #expect(action.methodName == "increment")
            #expect(action.targetIdentifier == "increment(_:context:)")
        }
    }

    @Test
    func ignoresValuesThatAreNotServices() async throws {
        try await withApplication { application in
            try await PageOwnedServices.register("not a service", on: application)
        }
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }
}

private distributed actor PageOwnedCounterService {
    typealias ActorSystem = WebActorSystem

    @ServerAction
    distributed func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        .invalidate(.page)
    }
}
