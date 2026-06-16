import Distributed
import SwiftWeb

distributed actor CounterService {
    typealias ActorSystem = WebActorSystem
    private var value = 0

    distributed func currentValue() async throws -> Int {
        value
    }

    @ServerAction
    distributed func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        value += 1
        return .invalidate(.page)
    }

    @ServerAction
    distributed func decrement(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        value -= 1
        return .invalidate(.page)
    }
}
