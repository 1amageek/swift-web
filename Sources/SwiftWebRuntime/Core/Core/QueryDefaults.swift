public protocol DefaultValueProvider: Sendable {
    associatedtype Value: Codable & Sendable

    static var defaultValue: Value { get }
}

@propertyWrapper
public struct Default<Provider: DefaultValueProvider>: Codable, Sendable {
    public var wrappedValue: Provider.Value

    public init() {
        self.wrappedValue = Provider.defaultValue
    }

    public init(wrappedValue: Provider.Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Provider.Value.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode<Provider: DefaultValueProvider>(
        _ type: Default<Provider>.Type,
        forKey key: Key
    ) throws -> Default<Provider> {
        try decodeIfPresent(type, forKey: key) ?? Default<Provider>()
    }
}

public enum DefaultFalse: DefaultValueProvider {
    public static let defaultValue = false
}

public enum DefaultTrue: DefaultValueProvider {
    public static let defaultValue = true
}

public enum DefaultZeroInt: DefaultValueProvider {
    public static let defaultValue = 0
}

public enum DefaultOneInt: DefaultValueProvider {
    public static let defaultValue = 1
}

public enum DefaultEmptyString: DefaultValueProvider {
    public static let defaultValue = ""
}
