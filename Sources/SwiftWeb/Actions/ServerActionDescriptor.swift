import Distributed
import Foundation
import Vapor

public struct ServerActionDescriptor: Sendable {
    public let actorName: String
    public let methodName: String
    public let targetIdentifier: String
    public let inputType: String
    public let outputType: String
    public let capabilityToken: String
    private let encodeInputData: @Sendable (Request) async throws -> Data
    private let encodeResponse: @Sendable (Data, Request) async throws -> Response
    private let invokeAction: @Sendable (any Sendable, Data, Data) async throws -> Data

    public init<Act, Input, Output>(
        actorType: Act.Type,
        actorName: String,
        methodName: String,
        targetIdentifier: String? = nil,
        inputType: Input.Type,
        outputType: Output.Type,
        capabilityToken: String = "",
        invoke: @Sendable @escaping (Act, Input, ActionInvocationContext) async throws -> Output
    ) where Act: DistributedActor & Sendable, Input: Codable & Sendable, Output: Codable & Sendable {
        self.actorName = actorName
        self.methodName = methodName
        self.targetIdentifier = targetIdentifier ?? methodName
        self.inputType = String(reflecting: Input.self)
        self.outputType = String(reflecting: Output.self)
        self.capabilityToken = capabilityToken
        self.encodeInputData = { request in
            let input = try await request.content.decode(Input.self)
            return try JSONEncoder().encode(input)
        }
        self.encodeResponse = { data, request in
            if Output.self == ActionResult.self {
                let result = try JSONDecoder().decode(ActionResult.self, from: data)
                return try await result.encodeResponse(for: request)
            }

            return Response(
                status: .ok,
                headers: [.contentType: "application/json; charset=utf-8"],
                body: .init(data: data)
            )
        }
        self.invokeAction = { actor, inputData, contextData in
            guard let typedActor = actor as? Act else {
                throw Abort(.internalServerError, reason: "Server action actor type mismatch")
            }
            let input = try JSONDecoder().decode(Input.self, from: inputData)
            let context = try JSONDecoder().decode(ActionInvocationContext.self, from: contextData)
            let output = try await invoke(typedActor, input, context)
            return try JSONEncoder().encode(output)
        }
    }

    func encodedInputData(from request: Request) async throws -> Data {
        try await encodeInputData(request)
    }

    func invoke(on actor: any Sendable, inputData: Data, contextData: Data) async throws -> Data {
        try await invokeAction(actor, inputData, contextData)
    }

    func response(from data: Data, request: Request) async throws -> Response {
        try await encodeResponse(data, request)
    }
}
