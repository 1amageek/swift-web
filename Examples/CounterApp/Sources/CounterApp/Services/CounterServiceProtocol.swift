import Distributed
import SwiftWeb

@Resolvable
protocol CounterServiceProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func currentValue() async throws -> Int
    distributed func increment() async throws -> Int
    distributed func decrement() async throws -> Int
}
