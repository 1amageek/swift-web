import Distributed
import SwiftWeb

distributed actor CounterService: CounterServiceProtocol {
    typealias ActorSystem = WebActorSystem
    private var value = 0

    distributed func currentValue() async throws -> Int {
        value
    }

    distributed func increment() async throws -> Int {
        value += 1
        return value
    }

    distributed func decrement() async throws -> Int {
        value -= 1
        return value
    }

    @ServerAction
    distributed func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        _ = try await increment()
        return .invalidate(.page)
    }

    @ServerAction
    distributed func decrement(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        _ = try await decrement()
        return .invalidate(.page)
    }
}
