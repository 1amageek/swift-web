#if !hasFeature(Embedded)
enum SwiftWebActorTypeIDWireCoding {
    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> UInt64 {
        do {
            let encodedValue = try container.decode(String.self, forKey: key)
            guard let value = UInt64(encodedValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: container,
                    debugDescription: "Expected an unsigned 64-bit integer string"
                )
            }
            return value
        } catch let error as DecodingError {
            guard case .typeMismatch = error else {
                throw error
            }
            return try container.decode(UInt64.self, forKey: key)
        }
    }

    static func encode<Key: CodingKey>(
        _ value: UInt64,
        to container: inout KeyedEncodingContainer<Key>,
        forKey key: Key
    ) throws {
        try container.encode(String(value), forKey: key)
    }
}
#endif
