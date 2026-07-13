#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

/// A process-lifetime `WebActorPersistentStore` kept in memory. It survives
/// actor eviction within one process (so grain state is restored on
/// reactivation) but not process restart. Useful for the native host and for
/// tests; durable hosts install a store backed by real storage.
public final class InMemoryActorPersistentStore: WebActorPersistentStore {
    private let storage = Mutex<[String: [String: Data]]>([:])

    public init() {}

    public func load(actorID: String) async throws -> [String: Data]? {
        storage.withLock { $0[actorID] }
    }

    public func save(actorID: String, values: [String: Data]) async throws {
        storage.withLock { $0[actorID] = values }
    }
}
#endif
