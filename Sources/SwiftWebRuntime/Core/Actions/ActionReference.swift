#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
import SwiftHTML

public struct ActionReference<Input: Codable & Sendable, Output: Sendable>: Sendable, ActionRepresentable {
    public let path: String
    public let httpMethod: ServerActionMethod
    public let inputType: String
    public let outputType: String

    public init(
        path: String,
        httpMethod: ServerActionMethod = .post,
        inputType: String,
        outputType: String
    ) {
        self.path = path
        self.httpMethod = httpMethod
        self.inputType = inputType
        self.outputType = outputType
    }

    public init(
        path: String,
        httpMethod: ServerActionMethod = .post
    ) {
        self.init(
            path: path,
            httpMethod: httpMethod,
            inputType: String(reflecting: Input.self),
            outputType: String(reflecting: Output.self)
        )
    }

    public var method: FormMethod {
        httpMethod.formMethod
    }

    public var fields: [ActionField] {
        guard httpMethod.requiresFormMethodOverride else {
            return []
        }
        return [
            ActionField("__swiftweb_method", httpMethod.rawValue),
        ]
    }
}

public struct NoActionInput: Sendable {
    public init() {}
}

#if !hasFeature(Embedded)
extension ActionReference: Codable {}
#endif
#endif

#if !hasFeature(Embedded)
extension NoActionInput: Codable {}
#endif
