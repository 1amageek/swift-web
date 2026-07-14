import Synchronization

/// Application-scoped typed storage, replacing `Vapor.Application.storage`.
/// Values live in `RuntimeBox`es so recovery works on every profile
/// (Embedded Swift has no unconstrained dynamic casts).
public final class ApplicationStorage: Sendable {
    private let storage = Mutex<[ObjectIdentifier: any AnyRuntimeBox]>([:])

    public init() {}

    public subscript<Key: StorageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            storage.withLock { $0[ObjectIdentifier(key)].flatMap { unboxRuntimeValue($0, as: Key.Value.self) } }
        }
        set {
            storage.withLock {
                if let newValue {
                    $0[ObjectIdentifier(key)] = RuntimeBox(newValue)
                } else {
                    $0.removeValue(forKey: ObjectIdentifier(key))
                }
            }
        }
    }
}
