#if SWIFTWEB_ACTORS
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

public struct SwiftWebActorReminder: Sendable, Equatable {
    public let actorAddress: ActorAddress
    public let name: String
    public let fireDate: Date

    public init(actorAddress: ActorAddress, name: String, fireDate: Date) {
        self.actorAddress = actorAddress
        self.name = name
        self.fireDate = fireDate
    }
}

public protocol SwiftWebActorReminderStore: Sendable {
    func set(_ reminder: SwiftWebActorReminder) async throws
    func cancel(actorAddress: ActorAddress, name: String) async throws
    func pending(actorAddress: ActorAddress) async throws -> [SwiftWebActorReminder]
    func shutdown() async
}

public struct SwiftWebActorReminders: Sendable {
    private let actorAddress: ActorAddress
    private let backend: SwiftWebActorReminderBackend

    init(
        actorAddress: ActorAddress,
        backend: SwiftWebActorReminderBackend
    ) {
        self.actorAddress = actorAddress
        self.backend = backend
    }

    public func set(_ name: String, in delay: Duration) async throws {
        try await set(name, at: Date().addingTimeInterval(delay.timeInterval))
    }

    public func set(_ name: String, at fireDate: Date) async throws {
        let store = try backend.requireStore(for: actorAddress)
        try await store.set(
            SwiftWebActorReminder(
                actorAddress: actorAddress,
                name: name,
                fireDate: fireDate
            )
        )
    }

    public func cancel(_ name: String) async throws {
        let store = try backend.requireStore(for: actorAddress)
        try await store.cancel(actorAddress: actorAddress, name: name)
    }

    public func pending() async throws -> [SwiftWebActorReminder] {
        let store = try backend.requireStore(for: actorAddress)
        return try await store.pending(actorAddress: actorAddress)
    }
}

public enum SwiftWebActorReminderError: Error, Sendable, Equatable {
    case storeNotInstalled(actorAddress: ActorAddress)
    case actorNotRemindable(actorAddress: ActorAddress, name: String)
}

final class SwiftWebActorReminderBackend: Sendable {
    private let store: Mutex<(any SwiftWebActorReminderStore)?>

    init(store: (any SwiftWebActorReminderStore)? = nil) {
        self.store = Mutex(store)
    }

    func install(
        _ store: any SwiftWebActorReminderStore
    ) -> (any SwiftWebActorReminderStore)? {
        self.store.withLock { installed in
            let previous = installed
            installed = store
            return previous
        }
    }

    func removeStore() -> (any SwiftWebActorReminderStore)? {
        store.withLock { installed in
            let removed = installed
            installed = nil
            return removed
        }
    }

    func requireStore(
        for actorAddress: ActorAddress
    ) throws -> any SwiftWebActorReminderStore {
        guard let store = store.withLock({ $0 }) else {
            throw SwiftWebActorReminderError.storeNotInstalled(
                actorAddress: actorAddress
            )
        }
        return store
    }
}
#endif
