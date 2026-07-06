@testable import SwiftWeb
@testable import SwiftWebCore
import Testing

@Suite
struct SwiftWebPageOwnedServicesTests {
    @Test
    func registersPageOwnedServerActionHandlers() async throws {
        try await withApplication { application in
            let service = PageOwnedCounterService()

            try await PageOwnedServices.register(
                service,
                on: application,
                routes: application.routes,
                basePath: RoutePath("/counter")
            )

            let action = try application.swiftWebServerActions.action(
                method: .post,
                path: "/counter/increment"
            )
            #expect(action.path == "/counter/increment")
            #expect(action.method == .post)
            #expect(action.descriptor.path == "increment")
        }
    }

    @Test
    func ignoresValuesThatAreNotServices() async throws {
        try await withApplication { application in
            try await PageOwnedServices.register("not a service", on: application)
        }
    }

    @Test
    func ignoresPageStoredValuesThatDoNotOptIntoServerActions() async throws {
        try await withApplication { application in
            try await PageOwnedServices.register(
                NonServerActionPageValue() as Any,
                on: application,
                routes: application.routes,
                basePath: RoutePath("/counter")
            )
        }
    }

    @Test
    func registersPageStoredServicesThatOptIntoServerActions() async throws {
        try await withApplication { application in
            let service = PageOwnedCounterService()

            try await PageOwnedServices.register(
                service as Any,
                on: application,
                routes: application.routes,
                basePath: RoutePath("/counter")
            )

            let action = try application.swiftWebServerActions.action(
                method: .post,
                path: "/counter/increment"
            )
            #expect(action.path == "/counter/increment")
        }
    }

    @Test
    func rejectsDuplicateServerActionRouteRegistration() async throws {
        try await withApplication { application in
            let first = DuplicateActionService()
            let second = DuplicateActionService()

            try await PageOwnedServices.register(first, on: application)

            do {
                try await PageOwnedServices.register(second, on: application)
                Issue.record("Duplicate server action route should be rejected")
            } catch let abort as Abort {
                #expect(abort.status == .conflict)
            }
        }
    }

    @Test
    func registersDifferentMethodsAtSamePath() async throws {
        try await withApplication { application in
            let service = MultiMethodActionService()

            try await PageOwnedServices.register(service, on: application)

            let read = try application.swiftWebServerActions.action(method: .get, path: "item")
            let update = try application.swiftWebServerActions.action(method: .put, path: "item")
            #expect(read.method == .get)
            #expect(update.method == .put)
        }
    }

    private func withApplication(
        _ body: (TestWebApplication) async throws -> Void
    ) async throws {
        try await body(TestWebApplication())
    }
}

private actor PageOwnedCounterService: PageOwnedServerActions {
    @ServerAction(.post, "increment")
    func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        .invalidate(.page)
    }
}

private final class NonServerActionPageValue {}

private final class DuplicateActionService: Sendable {
    @ServerAction(.post, "submit")
    func submit(_ input: NoActionInput, context: ActionInvocationContext) throws -> ActionResult {
        .invalidate(.page)
    }
}

private final class MultiMethodActionService: Sendable {
    @ServerAction(.get, "item")
    func read(_ input: NoActionInput) throws -> ActionResult {
        .text("read")
    }

    @ServerAction(.put, "item")
    func update(_ input: NoActionInput) throws -> ActionResult {
        .text("update")
    }
}
