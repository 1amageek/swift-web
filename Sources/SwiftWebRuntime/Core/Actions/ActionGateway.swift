#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

public enum ActionGateway {
    @discardableResult
    public static func register(on application: Application) -> Route {
        application.routes.post("_swiftweb", "actions") { _ async throws -> Response in
            throw Abort(.gone, reason: "Global server action gateway has been replaced by page-local HTTP action routes")
        }
    }

    @discardableResult
    public static func register<Handler>(
        handler: Handler,
        descriptor: ServerActionDescriptor,
        path: RoutePath,
        on routes: any RoutesBuilder,
        application: Application
    ) throws -> Route where Handler: Sendable {
        let publicPath = path.string
        try application.swiftWebServerActions.register(
            handler: handler,
            descriptor: descriptor,
            path: publicPath
        )

        let route = routes.on(descriptor.method.httpMethod, path.webComponents) { request async throws -> Response in
            try await invoke(
                handler: handler,
                descriptor: descriptor,
                request: request,
                effectiveMethod: descriptor.method,
                metadata: nil
            )
        }

        if descriptor.method.requiresFormMethodOverride {
            routes.on(.post, path.webComponents) { request async throws -> Response in
                try SecurityRequestValidator.validateOrigin(request)
                let metadata = try await request.content.decode(ActionRequestMetadata.self)
                guard metadata.methodOverride == descriptor.method.rawValue else {
                    throw Abort(.methodNotAllowed, reason: "Server action method override is invalid")
                }
                return try await invoke(
                    handler: handler,
                    descriptor: descriptor,
                    request: request,
                    effectiveMethod: descriptor.method,
                    metadata: metadata
                )
            }
        }

        return route
    }

    private static func invoke(
        handler: any Sendable,
        descriptor: ServerActionDescriptor,
        request: Request,
        effectiveMethod: ServerActionMethod,
        metadata: ActionRequestMetadata?
    ) async throws -> Response {
        try SecurityRequestValidator.validateOrigin(request)
        let csrfToken = try await csrfToken(from: request, metadata: metadata)
        try SecurityRequestValidator.validateCSRF(request, suppliedCSRFToken: csrfToken)

        let context = ActionInvocationContext(request: request, method: effectiveMethod)
        let inputData = try await descriptor.encodedInputData(from: request)
        let contextData = try JSONEncoder().encode(context)
        let requestValues = RequestValues(request: request, params: NoParams(), searchParams: NoSearchParams())

        return try await RequestContext.withValue(requestValues) {
            let outputData = try await descriptor.invoke(
                on: handler,
                inputData: inputData,
                contextData: contextData
            )
            return try await descriptor.response(from: outputData, request: request)
        }
    }

    private static func csrfToken(
        from request: Request,
        metadata: ActionRequestMetadata?
    ) async throws -> String? {
        if let csrfToken = metadata?.csrfToken {
            return csrfToken
        }
        return try await SecurityRequestValidator.csrfToken(
            from: request,
            source: request.application.securityConfiguration.csrf.formTokenSource
        )
    }
}
#endif
