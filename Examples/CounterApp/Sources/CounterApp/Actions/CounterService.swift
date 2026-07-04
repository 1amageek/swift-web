import Distributed
import SwiftWeb

@ResolvableActor(CounterServiceProtocol.self)
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
}
