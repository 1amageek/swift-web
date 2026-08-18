import Distributed
import SwiftWeb

distributed actor CounterService {
    typealias ActorSystem = WebActorSystem
    private var value: Int = 0

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
