import ActorSystemCore
import Synchronization

enum SwiftWebActorActivationIdentity {
    final class Pending: Sendable {
        private let address: Mutex<ActorAddress?>

        init(_ address: ActorAddress) {
            self.address = Mutex(address)
        }

        func takeIfMatching(actorType: ActorTypeID) -> ActorAddress? {
            address.withLock { address in
                guard let pending = address, pending.type == actorType else {
                    return nil
                }
                address = nil
                return pending
            }
        }
    }

    @TaskLocal static var current: Pending?

    static func withValue<Result>(
        _ address: ActorAddress,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(Pending(address), operation: operation)
    }

    static func withValue<Result: Sendable>(
        _ address: ActorAddress,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await $current.withValue(Pending(address), operation: operation)
    }

    static func take(actorType: ActorTypeID) -> ActorAddress? {
        current?.takeIfMatching(actorType: actorType)
    }
}
