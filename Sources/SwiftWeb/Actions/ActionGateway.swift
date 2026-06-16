import Foundation

public enum ActionGateway {
    @discardableResult
    public static func register(on application: Application) -> Route {
        application.post("_swiftweb", "actions", ":actorName", ":methodName") { req async throws -> Response in
            let actorName = try req.parameters.require("actorName")
            let methodName = try req.parameters.require("methodName")
            try SecurityRequestValidator.validateOrigin(req)
            let metadata = try await req.content.decode(ActionRequestMetadata.self)
            try SecurityRequestValidator.validateCSRF(
                req,
                suppliedCSRFToken: metadata.csrfToken
            )
            let action = try application.swiftWebServerActions.action(
                actorName: actorName,
                methodName: methodName,
                metadata: metadata
            )
            let context = ActionInvocationContext(request: req, metadata: metadata)
            let inputData = try await action.descriptor.encodedInputData(from: req)
            let contextData = try JSONEncoder().encode(context)
            let requestValues = RequestValues(request: req, params: NoParams(), searchParams: NoSearchParams())

            return try await RequestContext.withValue(requestValues) {
                let outputData = try await action.descriptor.invoke(
                    on: action.actor,
                    inputData: inputData,
                    contextData: contextData
                )
                return try await action.descriptor.response(from: outputData, request: req)
            }
        }
    }
}
