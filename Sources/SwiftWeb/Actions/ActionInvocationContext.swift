import Foundation
import HTTPTypes

public struct ActionInvocationContext: Sendable, Codable {
    public let id: UUID
    public let requestPath: String
    public let method: String
    public let actorID: String?
    public let actionName: String?
    public let targetIdentifier: String?
    public let idempotencyKey: String?

    public init(
        id: UUID = UUID(),
        requestPath: String,
        method: String,
        actorID: String? = nil,
        actionName: String? = nil,
        targetIdentifier: String? = nil,
        idempotencyKey: String? = nil
    ) {
        self.id = id
        self.requestPath = requestPath
        self.method = method
        self.actorID = actorID
        self.actionName = actionName
        self.targetIdentifier = targetIdentifier
        self.idempotencyKey = idempotencyKey
    }

    public init(request: Request, metadata: ActionRequestMetadata = ActionRequestMetadata()) {
        self.id = UUID()
        self.requestPath = request.url.path
        self.method = request.method.rawValue
        self.actorID = metadata.actorID
        self.actionName = metadata.actionName
        self.targetIdentifier = metadata.targetIdentifier
        self.idempotencyKey = request.headers[HTTPField.Name("Idempotency-Key")!]
    }
}

public struct ActionRequestMetadata: Sendable, Codable {
    public let actorID: String?
    public let actionName: String?
    public let targetIdentifier: String?
    public let capabilityToken: String?
    public let csrfToken: String?

    public init(
        actorID: String? = nil,
        actionName: String? = nil,
        targetIdentifier: String? = nil,
        capabilityToken: String? = nil,
        csrfToken: String? = nil
    ) {
        self.actorID = actorID
        self.actionName = actionName
        self.targetIdentifier = targetIdentifier
        self.capabilityToken = capabilityToken
        self.csrfToken = csrfToken
    }

    enum CodingKeys: String, CodingKey {
        case actorID = "__swiftweb_actor_id"
        case actionName = "__swiftweb_action"
        case targetIdentifier = "__swiftweb_target"
        case capabilityToken = "__swiftweb_action_token"
        case csrfToken = "_csrf"
    }
}
