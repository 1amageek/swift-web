#if SWIFTWEB_ACTORS
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

#if SWIFTWEB_LEGACY_ACTORS
/// A typed state change published by a server actor's `@RemoteState`
/// property. The value crosses the wire as JSON: hosts fan changes out to
/// the client islands observing the actor (over the WebSocket actor
/// transport), where the matching client-side `@RemoteState` re-renders
/// the island.
public struct RemoteStateChange: Sendable, Equatable, Codable {
    /// The actor identity whose state changed.
    public let actorID: LegacyWebActorSystem.ActorID
    /// The `@RemoteState` key that changed.
    public let key: String
    /// The JSON-encoded new value.
    public let value: Data

    public init(actorID: LegacyWebActorSystem.ActorID, key: String, value: Data) {
        self.actorID = actorID
        self.key = key
        self.value = value
    }
}

/// Receives published state changes and fans them out to observers. The
/// WebSocket host routes changes to the client peers observing the actor;
/// tests can install a recording publisher.
public protocol WebActorStatePublisher: Sendable {
    func publish(_ change: RemoteStateChange) async
}
#endif

/// A property wrapper for actor-owned state that streams to client islands.
///
///     distributed actor TravelAgent {
///         @RemoteState("partial") var partial: String?
///     }
///
/// Writes publish a `RemoteStateChange` through the actor system's
/// installed state publisher. Publishing requires activation by either the
/// concrete `SwiftWebActorHost` or the explicit legacy actor system, which
/// binds the property to the actor identity. Setting a value without a binding
/// keeps it locally and publishes nothing; streaming is a host capability.
@propertyWrapper
public struct RemoteState<Value: Codable & Sendable>: Sendable {
    private let box: RemoteStateBox<Value>

    public init(wrappedValue: Value, _ key: String) {
        self.box = RemoteStateBox(key: key, value: wrappedValue)
        RemoteStateActivationContext.register(box)
    }

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.update(newValue) }
    }
}

/// The type-erased binding surface the actor system uses to attach an
/// activated actor's identity and publisher to its `@RemoteState` boxes.
protocol RemoteStateBinding: AnyObject, Sendable {
#if SWIFTWEB_LEGACY_ACTORS
    func bind(actorID: LegacyWebActorSystem.ActorID, publisher: any WebActorStatePublisher)
#endif
    func bind(actorAddress: ActorAddress, publisher: any SwiftWebActorStatePublisher)
    func unbind() async
}

/// The backing store for one `@RemoteState` value: holds the current value
/// and publishes JSON-encoded changes once bound to an actor identity.
final class RemoteStateBox<Value: Codable & Sendable>: RemoteStateBinding {
    private struct State: Sendable {
        var value: Value
        var publication: RemoteStatePublication? = nil
    }

    let key: String
    private let state: Mutex<State>

    init(key: String, value: Value) {
        self.key = key
        self.state = Mutex(State(value: value))
    }

    var value: Value {
        state.withLock { $0.value }
    }

    func update(_ newValue: Value) {
        let key = self.key
        let reservation = state.withLock { state -> (RemoteStatePublicationQueue, UInt64)? in
            state.value = newValue
            guard let publication = state.publication else {
                return nil
            }
            return (publication.queue, publication.queue.reserve())
        }
        guard let (queue, generation) = reservation else {
            return
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(newValue)
        } catch {
            preconditionFailure("@RemoteState(\(key)) value failed to encode: \(error)")
        }
        if queue.commit(data, generation: generation) {
            queue.startDrain()
        }
    }

#if SWIFTWEB_LEGACY_ACTORS
    func bind(actorID: LegacyWebActorSystem.ActorID, publisher: any WebActorStatePublisher) {
        let key = self.key
        state.withLock { state in
            precondition(state.publication == nil, "Remote state was bound more than once")
            state.publication = RemoteStatePublication(
                queue: RemoteStatePublicationQueue { data in
                    await publisher.publish(
                        RemoteStateChange(
                            actorID: actorID,
                            key: key,
                            value: data
                        )
                    )
                }
            )
        }
    }
#endif

    func bind(actorAddress: ActorAddress, publisher: any SwiftWebActorStatePublisher) {
        let key = self.key
        state.withLock { state in
            precondition(state.publication == nil, "Remote state was bound more than once")
            state.publication = RemoteStatePublication(
                queue: RemoteStatePublicationQueue { data in
                    await publisher.publish(
                        SwiftWebRemoteStateChange(
                            actorAddress: actorAddress,
                            key: key,
                            value: data
                        )
                    )
                }
            )
        }
    }

    func unbind() async {
        let publication = state.withLock { state in
            let publication = state.publication
            state.publication = nil
            return publication
        }
        await publication?.queue.finish()
    }
}

private struct RemoteStatePublication: Sendable {
    let queue: RemoteStatePublicationQueue
}

/// Serializes publication for one state property without turning synchronous
/// property writes into suspension points. One publication may be executing
/// while one latest value waits; additional writes replace that waiting value.
private final class RemoteStatePublicationQueue: Sendable {
    private struct PendingValue: Sendable {
        let data: Data
    }

    private struct State: Sendable {
        var accepting = true
        var draining = false
        var preparing = 0
        var nextGeneration: UInt64 = 0
        var latestCommittedGeneration: UInt64 = 0
        var pending: PendingValue?
        var finishWaiters: [CheckedContinuation<Void, Never>] = []
    }

    private enum DrainStep {
        case publish(Data)
        case finished([CheckedContinuation<Void, Never>])
    }

    private let publish: @Sendable (Data) async -> Void
    private let state = Mutex(State())

    init(publish: @escaping @Sendable (Data) async -> Void) {
        self.publish = publish
    }

    /// Reserves the order of a synchronous property write before encoding runs
    /// outside locks. `finish()` waits for every reservation to commit.
    func reserve() -> UInt64 {
        state.withLock { state in
            precondition(state.accepting, "Remote state publication is closed")
            precondition(
                state.nextGeneration < UInt64.max,
                "Remote state publication generation exhausted"
            )
            precondition(
                state.preparing < Int.max,
                "Remote state publication reservation count exhausted"
            )
            state.nextGeneration += 1
            state.preparing += 1
            return state.nextGeneration
        }
    }

    /// Commits encoded bytes for a reserved write and returns whether the
    /// caller owns starting the drain after all locks have been released.
    func commit(_ data: Data, generation: UInt64) -> Bool {
        var completedWaiters: [CheckedContinuation<Void, Never>] = []
        let shouldStart = state.withLock { state in
            precondition(state.preparing > 0, "Remote state reservation underflow")
            state.preparing -= 1
            if generation > state.latestCommittedGeneration {
                state.latestCommittedGeneration = generation
                state.pending = PendingValue(
                    data: data
                )
            }
            if state.pending != nil, !state.draining {
                state.draining = true
                return true
            }
            if state.preparing == 0, !state.draining, state.pending == nil {
                completedWaiters = state.finishWaiters
                state.finishWaiters.removeAll(keepingCapacity: false)
            }
            return false
        }
        for waiter in completedWaiters {
            waiter.resume()
        }
        return shouldStart
    }

    func startDrain() {
        Task {
            await drain()
        }
    }

    func finish() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state in
                state.accepting = false
                guard state.draining || state.preparing > 0 else {
                    return true
                }
                state.finishWaiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    private func drain() async {
        while true {
            let step = state.withLock { state -> DrainStep in
                if let pending = state.pending {
                    state.pending = nil
                    return .publish(pending.data)
                }
                state.draining = false
                guard state.preparing == 0 else {
                    return .finished([])
                }
                let waiters = state.finishWaiters
                state.finishWaiters.removeAll(keepingCapacity: false)
                return .finished(waiters)
            }
            switch step {
            case .publish(let data):
                await publish(data)
            case .finished(let waiters):
                for waiter in waiters {
                    waiter.resume()
                }
                return
            }
        }
    }
}

/// Collects the `@RemoteState` boxes an actor declares while its factory
/// runs, so the actor system can bind them to the activating identity.
/// Mirrors `ActorStorageActivationContext`.
enum RemoteStateActivationContext {
    final class Collector: Sendable {
        private let boxes = Mutex<[any RemoteStateBinding]>([])

        func add(_ box: any RemoteStateBinding) {
            boxes.withLock { $0.append(box) }
        }

        func collected() -> [any RemoteStateBinding] {
            boxes.withLock { $0 }
        }
    }

    @TaskLocal static var current: Collector?

    static func withValue<Result>(
        _ value: Collector,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(value, operation: operation)
    }

    static func withValue<Result: Sendable>(
        _ value: Collector,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await $current.withValue(value, operation: operation)
    }

    static func register(_ box: any RemoteStateBinding) {
        current?.add(box)
    }
}
#endif
