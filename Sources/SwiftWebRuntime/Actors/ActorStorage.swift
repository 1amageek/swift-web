#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

/// A property wrapper that makes a distributed actor's own stored value durable
/// across activations — the actor's *grain state* in the Orleans sense.
///
///     distributed actor Counter {
///         @ActorStorage("count") var count = 0
///         distributed func increment() { count += 1 }
///     }
///
/// The value lives in memory during the actor's lifetime (so reads and writes
/// are ordinary, synchronous property access), and the actor system loads it
/// from the installed `WebActorPersistentStore` when the actor activates and
/// saves it after each invocation. When no store is installed the value is
/// purely in-memory — durability requires a store; this is a host configuration,
/// not a silent fallback (see `WebActorSystem.setPersistentStore`).
///
/// The wrapped value is held in a `Sendable` box the actor system can read and
/// restore without crossing the actor's isolation: the actor mutates it through
/// the wrapper, the runtime persists it through the box.
@propertyWrapper
public struct ActorStorage<Value: Codable & Sendable>: Sendable {
    private let box: PersistentBox<Value>

    /// - Parameters:
    ///   - wrappedValue: The initial value, used until state is loaded and when
    ///     no value was previously persisted.
    ///   - key: The storage key for this property within the actor. Must be
    ///     unique among the actor's `@ActorStorage` properties and stable across
    ///     versions (like `@AppStorage`'s key).
    public init(wrappedValue: Value, _ key: String) {
        self.box = PersistentBox(key: key, value: wrappedValue)
        ActorStorageActivationContext.register(box)
    }

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }
}

/// The type-erased contract the actor system uses to persist and restore a
/// `@ActorStorage` value without knowing its concrete type.
protocol PersistentValueBox: AnyObject, Sendable {
    var key: String { get }
    func encodedValue() throws -> Data
    func restore(from data: Data) throws
}

/// The `Sendable` backing store for one `@ActorStorage` value. Both the actor
/// (through the wrapper) and the actor system (through `PersistentValueBox`)
/// reach the value; the `Mutex` keeps that safe across the isolation boundary.
final class PersistentBox<Value: Codable & Sendable>: PersistentValueBox {
    let key: String
    private let state: Mutex<Value>

    init(key: String, value: Value) {
        self.key = key
        self.state = Mutex(value)
    }

    var value: Value {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    func encodedValue() throws -> Data {
        try JSONEncoder().encode(state.withLock { $0 })
    }

    func restore(from data: Data) throws {
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        state.withLock { $0 = decoded }
    }
}

/// Collects the `@ActorStorage` boxes an actor declares while its factory runs,
/// so the actor system can bind them to the activating ID. Mirrors
/// `WebActorActivationContext`: the system establishes a collector around the
/// factory call, and each wrapper's initializer registers into it.
enum ActorStorageActivationContext {
    final class Collector: Sendable {
        private let boxes = Mutex<[any PersistentValueBox]>([])

        func add(_ box: any PersistentValueBox) {
            boxes.withLock { $0.append(box) }
        }

        func collected() -> [any PersistentValueBox] {
            boxes.withLock { $0 }
        }
    }

    #if hasFeature(Embedded)
    nonisolated(unsafe) static var current: Collector?

    static func withValue<Result>(
        _ value: Collector,
        operation: () throws -> Result
    ) rethrows -> Result {
        let previous = current
        current = value
        defer { current = previous }
        return try operation()
    }
    #else
    @TaskLocal static var current: Collector?

    static func withValue<Result>(
        _ value: Collector,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(value, operation: operation)
    }
    #endif

    static func register(_ box: any PersistentValueBox) {
        current?.add(box)
    }
}
