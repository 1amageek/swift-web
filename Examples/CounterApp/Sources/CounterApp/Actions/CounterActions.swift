import SwiftWeb

actor CounterActions: PageOwnedServerActions {
    private let counterService: CounterService

    init(counterService: CounterService) {
        self.counterService = counterService
    }

    @ServerAction(.post, "increment")
    func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        _ = try await counterService.increment()
        return .invalidate(.page)
    }

    @ServerAction(.post, "decrement")
    func decrement(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        _ = try await counterService.decrement()
        return .invalidate(.page)
    }
}
