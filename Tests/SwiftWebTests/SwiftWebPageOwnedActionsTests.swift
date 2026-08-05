@testable import SwiftWeb
@testable import SwiftWebCore
import Testing

@Suite
struct SwiftWebPageOwnedActionsTests {
    @Test
    func registersPageOwnedServerActionHandlers() async throws {
        try await withRuntime { runtime in
            let handler = PageOwnedCounterHandler()

            try await PageOwnedActions.register(
                handler,
                in: runtime.pageActionContext,
                basePath: RoutePath("/counter")
            )

            let action = try runtime.swiftWebServerActions.action(
                method: .post,
                path: "/counter/increment"
            )
            #expect(action.path == "/counter/increment")
            #expect(action.method == .post)
            #expect(action.descriptor.path == "increment")
        }
    }

    @Test
    func ignoresValuesThatDoNotOwnActions() async throws {
        try await withRuntime { runtime in
            try await PageOwnedActions.registerActions(
                from: "not an action owner",
                in: runtime.pageActionContext
            )
        }
    }

    @Test
    func ignoresPageStoredValuesThatDoNotOptIntoServerActions() async throws {
        try await withRuntime { runtime in
            try await PageOwnedActions.registerActions(
                from: NonServerActionPageValue(),
                in: runtime.pageActionContext,
                basePath: RoutePath("/counter")
            )
        }
    }

    @Test
    func registersMarkedPageStoredValues() async throws {
        try await withRuntime { runtime in
            let handler = PageOwnedCounterHandler()

            try await PageOwnedActions.registerActions(
                from: handler,
                in: runtime.pageActionContext,
                basePath: RoutePath("/counter")
            )

            let action = try runtime.swiftWebServerActions.action(
                method: .post,
                path: "/counter/increment"
            )
            #expect(action.path == "/counter/increment")
        }
    }

    @Test
    func rejectsDuplicateServerActionRouteRegistration() async throws {
        try await withRuntime { runtime in
            let first = DuplicateActionHandler()
            let second = DuplicateActionHandler()

            try await PageOwnedActions.register(
                first,
                in: runtime.pageActionContext
            )

            do {
                try await PageOwnedActions.register(
                    second,
                    in: runtime.pageActionContext
                )
                Issue.record("Duplicate server action route should be rejected")
            } catch let abort as Abort {
                #expect(abort.status == .conflict)
            }
        }
    }

    @Test
    func registersDifferentMethodsAtSamePath() async throws {
        try await withRuntime { runtime in
            let handler = MultiMethodActionHandler()

            try await PageOwnedActions.register(
                handler,
                in: runtime.pageActionContext
            )

            let read = try runtime.swiftWebServerActions.action(method: .get, path: "/item")
            let update = try runtime.swiftWebServerActions.action(method: .put, path: "/item")
            #expect(read.method == .get)
            #expect(update.method == .put)
        }
    }

    private func withRuntime(
        _ body: (TestWebRuntime) async throws -> Void
    ) async throws {
        try await body(TestWebRuntime())
    }
}

private actor PageOwnedCounterHandler: PageOwnedServerActions {
    @ServerAction(.post, "increment")
    func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        .invalidate(.page)
    }
}

private final class NonServerActionPageValue: Sendable {}

private final class DuplicateActionHandler: Sendable {
    @ServerAction(.post, "submit")
    func submit(_ input: NoActionInput, context: ActionInvocationContext) throws -> ActionResult {
        .invalidate(.page)
    }
}

private final class MultiMethodActionHandler: Sendable {
    @ServerAction(.get, "item")
    func read(_ input: NoActionInput) throws -> ActionResult {
        .text("read")
    }

    @ServerAction(.put, "item")
    func update(_ input: NoActionInput) throws -> ActionResult {
        .text("update")
    }
}
