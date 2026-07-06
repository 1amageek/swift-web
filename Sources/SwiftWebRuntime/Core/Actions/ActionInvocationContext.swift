#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

public struct ActionInvocationContext: Sendable, Codable {
    public let id: UUID
    public let requestPath: String
    public let method: String
    public let idempotencyKey: String?

    public init(
        id: UUID = UUID(),
        requestPath: String,
        method: String,
        idempotencyKey: String? = nil
    ) {
        self.id = id
        self.requestPath = requestPath
        self.method = method
        self.idempotencyKey = idempotencyKey
    }

    public init(
        request: Request,
        method: ServerActionMethod? = nil
    ) {
        self.id = UUID()
        self.requestPath = request.url.path
        self.method = method?.rawValue ?? request.method.rawValue
        self.idempotencyKey = request.headers[HTTPField.Name("Idempotency-Key")!]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case requestPath
        case method
        case idempotencyKey
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            requestPath: try container.decode(String.self, forKey: .requestPath),
            method: try container.decode(String.self, forKey: .method),
            idempotencyKey: try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(requestPath, forKey: .requestPath)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
    }
}

public struct ActionRequestMetadata: Sendable, Codable {
    public let methodOverride: String?
    public let csrfToken: String?

    public init(
        methodOverride: String? = nil,
        csrfToken: String? = nil
    ) {
        self.methodOverride = methodOverride
        self.csrfToken = csrfToken
    }

    enum CodingKeys: String, CodingKey {
        case methodOverride = "__swiftweb_method"
        case csrfToken = "_csrf"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            methodOverride: try container.decodeIfPresent(String.self, forKey: .methodOverride),
            csrfToken: try container.decodeIfPresent(String.self, forKey: .csrfToken)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(methodOverride, forKey: .methodOverride)
        try container.encodeIfPresent(csrfToken, forKey: .csrfToken)
    }
}
