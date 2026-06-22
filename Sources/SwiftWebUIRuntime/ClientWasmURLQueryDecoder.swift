import Foundation
import SwiftHTML

public struct ClientWasmURLQueryDecoder: Sendable {
    public init() {}

    public func decode<Value: Decodable>(
        _ type: Value.Type,
        from search: String
    ) throws -> Value {
        let fields = ClientWasmURLQueryFields(search: search)
        return try Value(from: ClientWasmURLQueryRootDecoder(fields: fields))
    }
}

public extension ClientWasmBootstrapLocation {
    func decodeSearchParams<Value: Decodable>(
        _ type: Value.Type = Value.self,
        decoder: ClientWasmURLQueryDecoder = ClientWasmURLQueryDecoder()
    ) throws -> Value {
        try decoder.decode(type, from: search)
    }
}

private struct ClientWasmURLQueryFields {
    let values: [String: [String]]

    init(search: String) {
        let query = search.first == "?" ? String(search.dropFirst()) : search
        guard !query.isEmpty else {
            self.values = [:]
            return
        }

        var components = URLComponents()
        components.percentEncodedQuery = query
        var values: [String: [String]] = [:]
        for item in components.queryItems ?? [] {
            values[item.name, default: []].append(item.value ?? "")
        }
        self.values = values
    }
}

private struct ClientWasmURLQueryRootDecoder: Decoder {
    let fields: ClientWasmURLQueryFields
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    init(
        fields: ClientWasmURLQueryFields,
        codingPath: [any CodingKey] = [],
        userInfo: [CodingUserInfoKey: Any] = [:]
    ) {
        self.fields = fields
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    func container<Key: CodingKey>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(
            ClientWasmURLQueryKeyedContainer<Key>(
                fields: fields,
                codingPath: codingPath,
                userInfo: userInfo
            )
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        ClientWasmURLQueryUnkeyedContainer(
            values: [],
            codingPath: codingPath,
            userInfo: userInfo
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        ClientWasmURLQuerySingleValueContainer(
            values: [],
            codingPath: codingPath
        )
    }
}

private struct ClientWasmURLQueryValueDecoder: Decoder {
    let values: [String]
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    func container<Key: CodingKey>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Nested URL query objects are not supported"
            )
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        ClientWasmURLQueryUnkeyedContainer(
            values: values,
            codingPath: codingPath,
            userInfo: userInfo
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        ClientWasmURLQuerySingleValueContainer(
            values: values,
            codingPath: codingPath
        )
    }
}

private struct ClientWasmURLQueryKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let fields: ClientWasmURLQueryFields
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    var allKeys: [Key] {
        fields.values.keys.compactMap(Key.init(stringValue:))
    }

    func contains(_ key: Key) -> Bool {
        fields.values[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        fields.values[key.stringValue] == nil
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try singleValue(forKey: key).decode(type)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try singleValue(forKey: key).decode(type)
    }

    func decode<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> Value {
        try Value(from: valueDecoder(forKey: key))
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw unsupportedNestedValue(forKey: key)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        throw unsupportedNestedValue(forKey: key)
    }

    func superDecoder() throws -> any Decoder {
        ClientWasmURLQueryValueDecoder(values: [], codingPath: codingPath, userInfo: userInfo)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        try valueDecoder(forKey: key)
    }

    private func valueDecoder(forKey key: Key) throws -> ClientWasmURLQueryValueDecoder {
        guard let values = fields.values[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Missing URL query value for '\(key.stringValue)'"
                )
            )
        }
        return ClientWasmURLQueryValueDecoder(
            values: values,
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
    }

    private func singleValue(forKey key: Key) throws -> ClientWasmURLQuerySingleValueContainer {
        let decoder = try valueDecoder(forKey: key)
        return ClientWasmURLQuerySingleValueContainer(
            values: decoder.values,
            codingPath: decoder.codingPath
        )
    }

    private func unsupportedNestedValue(forKey key: Key) -> DecodingError {
        DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Nested URL query values are not supported"
            )
        )
    }
}

private struct ClientWasmURLQueryUnkeyedContainer: UnkeyedDecodingContainer {
    let values: [String]
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    private(set) var currentIndex = 0

    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }

    // A repeated query parameter (`?tags=a&tags=b`) decodes as an array of
    // present string values; it never carries a nil hole between elements, so an
    // element is never absent. (A wholly missing optional value is handled by the
    // single-value container's `decodeNil`, which reports emptiness.)
    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: String.Type) throws -> String {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try nextSingleValue().decode(type)
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try nextSingleValue().decode(type)
    }

    mutating func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try Value(from: nextDecoder())
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw unsupportedNestedValue()
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw unsupportedNestedValue()
    }

    mutating func superDecoder() throws -> any Decoder {
        try nextDecoder()
    }

    private mutating func nextDecoder() throws -> ClientWasmURLQueryValueDecoder {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "No more URL query values are available"
                )
            )
        }
        let value = values[currentIndex]
        let key = ClientWasmURLQueryIndexKey(index: currentIndex)
        currentIndex += 1
        return ClientWasmURLQueryValueDecoder(
            values: [value],
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
    }

    private mutating func nextSingleValue() throws -> ClientWasmURLQuerySingleValueContainer {
        let decoder = try nextDecoder()
        return ClientWasmURLQuerySingleValueContainer(
            values: decoder.values,
            codingPath: decoder.codingPath
        )
    }

    private func unsupportedNestedValue() -> DecodingError {
        DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Nested URL query values are not supported"
            )
        )
    }
}

private struct ClientWasmURLQuerySingleValueContainer: SingleValueDecodingContainer {
    let values: [String]
    let codingPath: [any CodingKey]

    func decodeNil() -> Bool {
        values.isEmpty
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        let raw = try firstValue()
        switch raw.lowercased() {
        case "true", "1", "yes", "on":
            return true
        case "false", "0", "no", "off":
            return false
        default:
            throw corruptedValue(raw, expected: "Bool")
        }
    }

    func decode(_ type: String.Type) throws -> String {
        try firstValue()
    }

    func decode(_ type: Double.Type) throws -> Double {
        let raw = try firstValue()
        guard let value = Double(raw) else {
            throw corruptedValue(raw, expected: "Double")
        }
        return value
    }

    func decode(_ type: Float.Type) throws -> Float {
        let raw = try firstValue()
        guard let value = Float(raw) else {
            throw corruptedValue(raw, expected: "Float")
        }
        return value
    }

    func decode(_ type: Int.Type) throws -> Int {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeFixedWidthInteger(type)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeFixedWidthInteger(type)
    }

    func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try Value(from: ClientWasmURLQueryValueDecoder(
            values: values,
            codingPath: codingPath,
            userInfo: [:]
        ))
    }

    private func firstValue() throws -> String {
        guard let value = values.first else {
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Missing URL query value"
                )
            )
        }
        return value
    }

    private func decodeFixedWidthInteger<Value: FixedWidthInteger>(
        _ type: Value.Type
    ) throws -> Value {
        let raw = try firstValue()
        guard let value = Value(raw) else {
            throw corruptedValue(raw, expected: String(describing: Value.self))
        }
        return value
    }

    private func corruptedValue(_ raw: String, expected: String) -> DecodingError {
        DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not decode '\(raw)' as \(expected)"
            )
        )
    }
}

private struct ClientWasmURLQueryIndexKey: CodingKey {
    let intValue: Int?
    let stringValue: String

    init(index: Int) {
        self.intValue = index
        self.stringValue = "Index \(index)"
    }

    init?(intValue: Int) {
        self.init(index: intValue)
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}
