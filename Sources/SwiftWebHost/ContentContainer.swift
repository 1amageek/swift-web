#if !hasFeature(Embedded)
/// Decodes the request body (JSON / form / multipart) as `Decodable` content.
/// The decoding strategy is supplied by the host adapter so each host keeps
/// its native content negotiation.
public struct ContentContainer: Sendable {
    private let decoder: @Sendable (any Decodable.Type) async throws -> any Decodable
    private let fieldDecoder: @Sendable (any Decodable.Type, String) async throws -> any Decodable

    public init(
        decoder: @escaping @Sendable (any Decodable.Type) async throws -> any Decodable,
        fieldDecoder: @escaping @Sendable (any Decodable.Type, String) async throws -> any Decodable
    ) {
        self.decoder = decoder
        self.fieldDecoder = fieldDecoder
    }

    public func decode<Content: Decodable>(_ type: Content.Type) async throws -> Content {
        let decoded = try await decoder(type)
        guard let value = decoded as? Content else {
            throw RequestError.decodingTypeMismatch(String(describing: type))
        }
        return value
    }

    /// Decodes a single named field of the request body (e.g. one multipart part).
    public func get<Content: Decodable>(_ type: Content.Type, at name: String) async throws -> Content {
        let decoded = try await fieldDecoder(type, name)
        guard let value = decoded as? Content else {
            throw RequestError.decodingTypeMismatch(String(describing: type))
        }
        return value
    }
}
#else
/// Embedded profile: request-body `Decodable` decoding is unavailable
/// (no Codable). The type remains so `Request`'s shape is identical;
/// hosts construct it empty.
public struct ContentContainer: Sendable {
    public init() {}
}
#endif
