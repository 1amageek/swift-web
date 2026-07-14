/// The host-neutral session the SwiftWeb core programs against.
/// Host adapters supply the closures from their native session store.
public struct RequestSession: Sendable {
    public static let userIDKey = "swiftweb.userID"
    public static let authenticationStateKey = "swiftweb.isAuthenticated"

    private let identifierReader: @Sendable () -> String?
    private let valuesReader: @Sendable () -> [String: String]
    private let valueReader: @Sendable (String) -> String?
    private let valueWriter: @Sendable (String, String?) -> Void
    private let destroyHandler: @Sendable () -> Void

    public var id: String? {
        identifierReader()
    }

    public var values: [String: String] {
        valuesReader()
    }

    public var userID: String? {
        self[Self.userIDKey]
    }

    public var isAuthenticated: Bool {
        bool(forKey: Self.authenticationStateKey) ?? (userID != nil)
    }

    public init(
        identifierReader: @Sendable @escaping () -> String?,
        valuesReader: @Sendable @escaping () -> [String: String],
        valueReader: @Sendable @escaping (String) -> String?,
        valueWriter: @Sendable @escaping (String, String?) -> Void,
        destroyHandler: @Sendable @escaping () -> Void
    ) {
        self.identifierReader = identifierReader
        self.valuesReader = valuesReader
        self.valueReader = valueReader
        self.valueWriter = valueWriter
        self.destroyHandler = destroyHandler
    }

    public subscript(_ key: String) -> String? {
        get {
            value(forKey: key)
        }
        nonmutating set {
            setValue(newValue, forKey: key)
        }
    }

    public func value(forKey key: String) -> String? {
        valueReader(key)
    }

    public func setValue(_ value: String?, forKey key: String) {
        valueWriter(key, value)
    }

    public func bool(forKey key: String) -> Bool? {
        guard let value = value(forKey: key) else {
            return nil
        }

        switch value.lowercased() {
        case "true", "1", "yes":
            return true
        case "false", "0", "no":
            return false
        default:
            return nil
        }
    }

    public func setBool(_ value: Bool?, forKey key: String) {
        setValue(value.map { $0 ? "true" : "false" }, forKey: key)
    }

    public func authenticate(userID: String) {
        setValue(userID, forKey: Self.userIDKey)
        setBool(true, forKey: Self.authenticationStateKey)
    }

    public func clearAuthentication() {
        setValue(nil, forKey: Self.userIDKey)
        setValue(nil, forKey: Self.authenticationStateKey)
    }

    public func destroy() {
        destroyHandler()
    }
}
