import Synchronization

/// Framework-owned typed storage shared by rendering and request execution.
/// Values live in `RuntimeBox`es so recovery works on every supported profile.
@_spi(Hosting)
public final class RuntimeStorage: Sendable {
    private let values = Mutex<[ObjectIdentifier: any AnyRuntimeBox]>([:])

    public init() {}

    public subscript<Key: RuntimeStorageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            values.withLock { values in
                values[ObjectIdentifier(key)].flatMap {
                    unboxRuntimeValue($0, as: Key.Value.self)
                }
            }
        }
        set {
            values.withLock { values in
                if let newValue {
                    values[ObjectIdentifier(key)] = RuntimeBox(newValue)
                } else {
                    values.removeValue(forKey: ObjectIdentifier(key))
                }
            }
        }
    }
}

@_spi(Hosting)
public protocol RuntimeStorageKey {
    associatedtype Value: Sendable
}
