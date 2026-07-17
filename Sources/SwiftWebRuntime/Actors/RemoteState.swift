#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

/// A typed state change published by a server actor's `@RemoteState`
/// property. The value crosses the wire as JSON: hosts fan changes out to
/// the client islands observing the actor (over the WebSocket actor
/// transport), where the matching client-side `@RemoteState` re-renders
/// the island.
public struct RemoteStateChange: Sendable, Equatable, Codable {
    /// The actor identity whose state changed.
    public let actorID: WebActorSystem.ActorID
    /// The `@RemoteState` key that changed.
    public let key: String
    /// The JSON-encoded new value.
    public let value: Data

    public init(actorID: WebActorSystem.ActorID, key: String, value: Data) {
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

/// A property wrapper for actor-owned state that streams to client islands.
///
///     distributed actor TravelAgent {
///         @RemoteState("partial") var partial: String?
///     }
///
/// Writes publish a `RemoteStateChange` through the actor system's
/// installed `WebActorStatePublisher`. Publishing requires the actor to be
/// activated by `WebActorSystem` (which binds the property to the actor's
/// identity) and a publisher to be installed; setting the value without a
/// binding keeps the value locally and publishes nothing — reads stay
/// correct, streaming is a host capability.
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
    func bind(actorID: WebActorSystem.ActorID, publisher: any WebActorStatePublisher)
}

/// The backing store for one `@RemoteState` value: holds the current value
/// and publishes JSON-encoded changes once bound to an actor identity.
final class RemoteStateBox<Value: Codable & Sendable>: RemoteStateBinding {
    private struct State: Sendable {
        var value: Value
        var actorID: WebActorSystem.ActorID?
        var publisher: (any WebActorStatePublisher)?
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
        let published: (WebActorSystem.ActorID, any WebActorStatePublisher)? = state.withLock { state in
            state.value = newValue
            guard let actorID = state.actorID, let publisher = state.publisher else {
                return nil
            }
            return (actorID, publisher)
        }
        guard let (actorID, publisher) = published else {
            return
        }
        // Encoding happens outside the lock; an unencodable value is a
        // programmer error surfaced loudly rather than dropped silently.
        do {
            let data = try JSONEncoder().encode(newValue)
            let change = RemoteStateChange(actorID: actorID, key: key, value: data)
            Task {
                await publisher.publish(change)
            }
        } catch {
            preconditionFailure("@RemoteState(\(key)) value failed to encode: \(error)")
        }
    }

    func bind(actorID: WebActorSystem.ActorID, publisher: any WebActorStatePublisher) {
        state.withLock { state in
            state.actorID = actorID
            state.publisher = publisher
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

    static func register(_ box: any RemoteStateBinding) {
        current?.add(box)
    }
}
#endif
