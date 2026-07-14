#if !hasFeature(Embedded)
/// Decodes `application/x-www-form-urlencoded` payloads and URL query strings
/// into `Decodable` values, replacing Vapor's URL-encoded form support for
/// hosts without it.
///
/// Supported shape: flat keys with scalar values; repeated keys decode as
/// arrays. This matches what SwiftWeb forms and search params emit.
public struct URLEncodedFormDecoder: Sendable {
    public init() {}

    public func decode<Value: Decodable>(_ type: Value.Type, from encoded: String) throws -> Value {
        let fields = Self.parse(encoded)
        return try Value(from: _FormDecoder(fields: fields, codingPath: []))
    }

    /// Parses via the shared `FormParsing` rules so Codable paths and the
    /// typed `QueryParameters` accessors read identical semantics.
    static func parse(_ encoded: String) -> [String: [String]] {
        FormParsing.parse(encoded)
    }
}

private struct _FormDecoder: Decoder {
    let fields: [String: [String]]
    let codingPath: [any CodingKey]

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(_FormKeyedContainer<Key>(fields: fields, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "URL-encoded form values require keyed decoding at the top level")
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "URL-encoded form values require keyed decoding at the top level")
        )
    }
}

private struct _FormKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let fields: [String: [String]]
    let codingPath: [any CodingKey]

    var allKeys: [Key] {
        fields.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        fields[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        !contains(key)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let value = try requireValue(forKey: key)
        guard let bool = _FormScalar.bool(from: value) else {
            throw invalidValue(value, forKey: key)
        }
        return bool
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try requireValue(forKey: key)
    }

    func decode<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> Value {
        let values = try requireValues(forKey: key)
        return try _FormScalar.decode(Value.self, from: values, codingPath: codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "URL-encoded form values do not support nested containers")
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        _FormUnkeyedContainer(values: try requireValues(forKey: key), codingPath: codingPath + [key])
    }

    func superDecoder() throws -> any Decoder {
        _FormDecoder(fields: fields, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        _FormScalarDecoder(value: try requireValue(forKey: key), codingPath: codingPath + [key])
    }

    private func requireValues(forKey key: Key) throws -> [String] {
        guard let values = fields[key.stringValue], !values.isEmpty else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Missing form value '\(key.stringValue)'")
            )
        }
        return values
    }

    private func requireValue(forKey key: Key) throws -> String {
        try requireValues(forKey: key)[0]
    }

    private func invalidValue(_ value: String, forKey key: Key) -> DecodingError {
        DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Invalid form value '\(value)'")
        )
    }
}

private struct _FormUnkeyedContainer: UnkeyedDecodingContainer {
    let values: [String]
    let codingPath: [any CodingKey]
    var currentIndex = 0

    var count: Int? {
        values.count
    }

    var isAtEnd: Bool {
        currentIndex >= values.count
    }

    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Value.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Form value array is exhausted")
            )
        }
        let value = try _FormScalar.decode(Value.self, from: [values[currentIndex]], codingPath: codingPath)
        currentIndex += 1
        return value
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "URL-encoded form values do not support nested containers")
        )
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "URL-encoded form values do not support nested containers")
        )
    }

    mutating func superDecoder() throws -> any Decoder {
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "URL-encoded form values do not support super decoding")
        )
    }
}

private enum _FormScalar {
    static func bool(from value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "on":
            true
        case "false", "0", "no", "off", "":
            false
        default:
            nil
        }
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from values: [String],
        codingPath: [any CodingKey]
    ) throws -> Value {
        if Value.self == String.self {
            return values[0] as! Value
        }
        if Value.self == Bool.self {
            guard let bool = bool(from: values[0]) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid boolean form value '\(values[0])'")
                )
            }
            return bool as! Value
        }
        if let losslessType = Value.self as? any LosslessStringConvertible.Type,
           let value = losslessType.init(values[0]) as? Value {
            return value
        }
        return try Value(from: _FormValueDecoder(values: values, codingPath: codingPath))
    }
}

/// Decodes one field's values: scalars via a single-value container, arrays
/// (repeated keys) via an unkeyed container.
private struct _FormValueDecoder: Decoder, SingleValueDecodingContainer {
    let values: [String]
    let codingPath: [any CodingKey]

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Form value is scalar")
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        _FormUnkeyedContainer(values: values, codingPath: codingPath)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }

    func decodeNil() -> Bool {
        false
    }

    func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try _FormScalar.decode(Value.self, from: values, codingPath: codingPath)
    }
}

private struct _FormScalarDecoder: Decoder {
    let value: String
    let codingPath: [any CodingKey]

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Form value is scalar")
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        _FormUnkeyedContainer(values: [value], codingPath: codingPath)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        _FormValueDecoder(values: [value], codingPath: codingPath)
    }
}
#endif
