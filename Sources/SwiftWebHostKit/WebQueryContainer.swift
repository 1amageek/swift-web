/// Decodes the URL query string of a request.
/// The decoding strategy is supplied by the host adapter so each host keeps
/// its native semantics (nested keys, arrays, percent decoding).
public struct WebQueryContainer: Sendable {
    private let decoder: @Sendable (any Decodable.Type) throws -> any Decodable

    public init(decoder: @escaping @Sendable (any Decodable.Type) throws -> any Decodable) {
        self.decoder = decoder
    }

    public func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        let decoded = try decoder(type)
        guard let value = decoded as? Value else {
            throw WebRequestError.decodingTypeMismatch(String(describing: type))
        }
        return value
    }
}
