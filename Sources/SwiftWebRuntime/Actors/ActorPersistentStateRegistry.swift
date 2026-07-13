#if SWIFTWEB_ACTORS
import Synchronization

/// Tracks the `@ActorStorage` boxes bound to each active actor and drives their
/// load and save against the installed `WebActorPersistentStore`.
///
/// A binding is per activation: reactivating an evicted actor creates a fresh
/// binding with a fresh load gate, so state is reloaded from the store rather
/// than reusing the previous instance's already-loaded flag.
final class ActorPersistentStateRegistry: Sendable {
    private let bindings = Mutex<[String: Binding]>([:])

    /// Records the boxes an actor declared during activation. Actors with no
    /// `@ActorStorage` properties are not tracked.
    func bind(id: String, boxes: [any PersistentValueBox]) {
        guard !boxes.isEmpty else {
            return
        }
        bindings.withLock { $0[id] = Binding(boxes: boxes) }
    }

    /// Drops an actor's binding on eviction, so the next activation reloads.
    func forget(id: String) {
        bindings.withLock { $0[id] = nil }
    }

    /// Restores persisted values into the actor's boxes exactly once per
    /// activation, before the first invocation dispatches. A no-op for actors
    /// without `@ActorStorage`; with no store installed the values stay at their
    /// in-memory defaults.
    func loadIfNeeded(id: String, store: (any WebActorPersistentStore)?) async throws {
        guard let binding = bindings.withLock({ $0[id] }) else {
            return
        }
        try await binding.gate.loadOnce {
            guard let store, let values = try await store.load(actorID: id) else {
                return
            }
            for box in binding.boxes {
                if let data = values[box.key] {
                    try box.restore(from: data)
                }
            }
        }
    }

    /// Persists the actor's current box values after an invocation. A no-op when
    /// no store is installed or the actor has no `@ActorStorage`.
    func save(id: String, store: (any WebActorPersistentStore)?) async throws {
        guard let store, let binding = bindings.withLock({ $0[id] }) else {
            return
        }
        var values: [String: Data] = [:]
        for box in binding.boxes {
            values[box.key] = try box.encodedValue()
        }
        try await store.save(actorID: id, values: values)
    }
}

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

private final class Binding: Sendable {
    let boxes: [any PersistentValueBox]
    let gate = LoadGate()

    init(boxes: [any PersistentValueBox]) {
        self.boxes = boxes
    }
}

/// Serializes the one-time load for a single activation: concurrent first
/// invocations await the same load instead of racing to overwrite each other.
private actor LoadGate {
    private var task: Task<Void, any Error>?
    private var done = false

    func loadOnce(_ operation: @Sendable @escaping () async throws -> Void) async throws {
        if done {
            return
        }
        if let task {
            try await task.value
            return
        }
        let task = Task { try await operation() }
        self.task = task
        defer { self.task = nil }
        try await task.value
        done = true
    }
}
#endif
