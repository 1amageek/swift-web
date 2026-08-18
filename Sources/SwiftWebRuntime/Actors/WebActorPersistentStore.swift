#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// A backing store for `@ActorStorage` grain state, keyed by actor ID. Concrete
/// hosts install it on `SwiftWebActorHost`; the explicit legacy actor system
/// accepts the same contract during migration.
///
/// A value is the per-key encoded state of one actor: `[storageKey: encoded]`.
/// `load` returns `nil` when the actor has never persisted state, so the actor
/// keeps its `@ActorStorage` default values.
public protocol WebActorPersistentStore: Sendable {
    func load(actorID: String) async throws -> [String: Data]?
    func save(actorID: String, values: [String: Data]) async throws
}
#endif
