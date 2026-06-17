import Distributed
import SwiftWebActors

@Resolvable
protocol CounterServiceProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func currentValue() async throws -> Int
    distributed func increment() async throws -> Int
    distributed func decrement() async throws -> Int
}
