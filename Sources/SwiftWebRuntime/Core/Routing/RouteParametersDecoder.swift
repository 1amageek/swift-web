import Foundation

public struct RouteParametersDecoder: Sendable {
    private let request: Request

    public init(_ request: Request) {
        self.request = request
    }

    public func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        if Value.self == NoParams.self {
            return NoParams() as! Value
        }
        let decoder = _RouteParametersDecoder(request: request, codingPath: [])
        return try Value(from: decoder)
    }
}

private struct _RouteParametersDecoder: Decoder {
    let request: Request
    let codingPath: [any CodingKey]

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(RouteParametersKeyedContainer<Key>(
            request: request,
            codingPath: codingPath
        ))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Route parameters do not support unkeyed containers")
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Route parameters require keyed decoding")
        )
    }
}

private struct RouteParametersKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let request: Request
    let codingPath: [any CodingKey]

    var allKeys: [Key] {
        []
    }

    func contains(_ key: Key) -> Bool {
        request.parameters.get(key.stringValue) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        !contains(key)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try requireValue(forKey: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeValue(type, forKey: key)
    }

    func decode<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> Value {
        let string = try requireValue(forKey: key)
        return try RouteParameterValueDecoder.decode(
            Value.self,
            from: string,
            codingPath: codingPath + [key]
        )
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Route parameters do not support nested containers")
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Route parameters do not support nested containers")
        )
    }

    func superDecoder() throws -> any Decoder {
        _RouteParametersDecoder(request: request, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        _RouteParameterSingleValueDecoder(value: try requireValue(forKey: key), codingPath: codingPath + [key])
    }

    private func requireValue(forKey key: Key) throws -> String {
        guard let value = request.parameters.get(key.stringValue) else {
            throw Abort(.badRequest, reason: "Missing route parameter '\(key.stringValue)'")
        }
        return value
    }

    private func decodeValue<Value: LosslessStringConvertible>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> Value {
        let string = try requireValue(forKey: key)
        guard let value = Value(string) else {
            throw Abort(.badRequest, reason: "Invalid route parameter '\(key.stringValue)'")
        }
        return value
    }
}

private enum RouteParameterValueDecoder {
    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from string: String,
        codingPath: [any CodingKey]
    ) throws -> Value {
        if Value.self == String.self {
            return string as! Value
        }
        if Value.self == UUID.self {
            guard let uuid = UUID(uuidString: string) else {
                throw Abort(.badRequest, reason: "Invalid UUID route parameter")
            }
            return uuid as! Value
        }
        if let losslessType = Value.self as? any LosslessStringConvertible.Type,
           let value = losslessType.init(string) as? Value {
            return value
        }

        return try Value(from: _RouteParameterSingleValueDecoder(value: string, codingPath: codingPath))
    }
}

private struct _RouteParameterSingleValueDecoder: Decoder, SingleValueDecodingContainer {
    let value: String
    let codingPath: [any CodingKey]

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Route parameter value is scalar")
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Route parameter value is scalar")
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }

    func decodeNil() -> Bool {
        false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try decodeLossless(type)
    }

    func decode(_ type: String.Type) throws -> String {
        value
    }

    func decode(_ type: Double.Type) throws -> Double {
        try decodeLossless(type)
    }

    func decode(_ type: Float.Type) throws -> Float {
        try decodeLossless(type)
    }

    func decode(_ type: Int.Type) throws -> Int {
        try decodeLossless(type)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeLossless(type)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeLossless(type)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeLossless(type)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeLossless(type)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try decodeLossless(type)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeLossless(type)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeLossless(type)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeLossless(type)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeLossless(type)
    }

    func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try RouteParameterValueDecoder.decode(Value.self, from: value, codingPath: codingPath)
    }

    private func decodeLossless<Value: LosslessStringConvertible>(_ type: Value.Type) throws -> Value {
        guard let decoded = Value(value) else {
            throw Abort(.badRequest, reason: "Invalid route parameter value")
        }
        return decoded
    }
}
