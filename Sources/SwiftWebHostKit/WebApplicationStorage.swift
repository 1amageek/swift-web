import Synchronization

/// Application-scoped typed storage, replacing `Vapor.Application.storage`.
public final class WebApplicationStorage: Sendable {
    private let storage = Mutex<[ObjectIdentifier: any Sendable]>([:])

    public init() {}

    public subscript<Key: WebStorageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            storage.withLock { $0[ObjectIdentifier(key)] as? Key.Value }
        }
        set {
            storage.withLock { $0[ObjectIdentifier(key)] = newValue }
        }
    }
}
