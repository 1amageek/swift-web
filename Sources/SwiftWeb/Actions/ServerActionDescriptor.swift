import Foundation
import Vapor

public struct ServerActionDescriptor: Sendable {
    public let method: ServerActionMethod
    public let path: String
    public let inputType: String
    public let outputType: String
    private let encodeInputData: @Sendable (Request) async throws -> Data
    private let encodeResponse: @Sendable (Data, Request) async throws -> Response
    private let invokeAction: @Sendable (any Sendable, Data, Data) async throws -> Data

    public init<Handler, Input, Output>(
        handlerType: Handler.Type,
        method: ServerActionMethod,
        path: String,
        inputType: Input.Type,
        outputType: Output.Type,
        invoke: @Sendable @escaping (Handler, Input, ActionInvocationContext) async throws -> Output
    ) where Handler: Sendable, Input: Codable & Sendable, Output: Codable & Sendable {
        self.method = method
        self.path = path
        self.inputType = String(reflecting: Input.self)
        self.outputType = String(reflecting: Output.self)
        self.encodeInputData = { request in
            let input: Input
            if method == .get {
                input = try request.query.decode(Input.self)
            } else {
                input = try await request.content.decode(Input.self)
            }
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
        self.invokeAction = { handler, inputData, contextData in
            guard let typedHandler = handler as? Handler else {
                throw Abort(.internalServerError, reason: "Server action handler type mismatch")
            }
            let input = try JSONDecoder().decode(Input.self, from: inputData)
            let context = try JSONDecoder().decode(ActionInvocationContext.self, from: contextData)
            let output = try await invoke(typedHandler, input, context)
            return try JSONEncoder().encode(output)
        }
    }

    func encodedInputData(from request: Request) async throws -> Data {
        try await encodeInputData(request)
    }

    func invoke(on handler: any Sendable, inputData: Data, contextData: Data) async throws -> Data {
        try await invokeAction(handler, inputData, contextData)
    }

    func response(from data: Data, request: Request) async throws -> Response {
        try await encodeResponse(data, request)
    }
}
