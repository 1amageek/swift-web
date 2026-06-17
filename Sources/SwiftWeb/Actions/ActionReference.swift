import SwiftHTML

public struct ActionReference<Input: Codable & Sendable, Output: Sendable>: Sendable, Codable, ActionRepresentable {
    public let actorID: String
    public let actorName: String
    public let methodName: String
    public let targetIdentifier: String
    public let inputType: String
    public let outputType: String
    public let capabilityToken: String

    public init(
        actorID: String,
        actorName: String,
        methodName: String,
        targetIdentifier: String? = nil,
        inputType: String,
        outputType: String,
        capabilityToken: String = ""
    ) {
        self.actorID = actorID
        self.actorName = actorName
        self.methodName = methodName
        self.targetIdentifier = targetIdentifier ?? methodName
        self.inputType = inputType
        self.outputType = outputType
        self.capabilityToken = capabilityToken
    }

    public init(
        actorID: String? = nil,
        actorName: String,
        methodName: String,
        targetIdentifier: String? = nil,
        capabilityToken: String = ""
    ) {
        self.init(
            actorID: actorID ?? actorName,
            actorName: actorName,
            methodName: methodName,
            targetIdentifier: targetIdentifier,
            inputType: String(reflecting: Input.self),
            outputType: String(reflecting: Output.self),
            capabilityToken: capabilityToken
        )
    }

    public var path: String {
        "/_swiftweb/actions/\(actorName)/\(methodName)"
    }

    public var method: FormMethod {
        .post
    }

    public var fields: [ActionField] {
        var fields = [
            ActionField("__swiftweb_actor_id", actorID),
            ActionField("__swiftweb_action", methodName),
            ActionField("__swiftweb_target", targetIdentifier),
        ]
        if !capabilityToken.isEmpty {
            fields.append(ActionField("__swiftweb_action_token", capabilityToken))
        }
        return fields
    }

    public func resolved(actorID: String, capabilityToken: String? = nil) -> Self {
        Self(
            actorID: actorID,
            actorName: actorName,
            methodName: methodName,
            targetIdentifier: targetIdentifier,
            inputType: inputType,
            outputType: outputType,
            capabilityToken: capabilityToken ?? self.capabilityToken
        )
    }

}

public struct NoActionInput: Codable, Sendable {
    public init() {}
}
