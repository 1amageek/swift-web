public protocol UploadAction: SendableMetatype {
    associatedtype Params: Decodable & Sendable = NoParams
    associatedtype Input: Decodable & Sendable

    init()

    func upload(_ context: UploadContext<Params, Input>) async throws -> ActionResult
}

public enum UploadRoute {
    @discardableResult
    public static func post<Action: UploadAction>(
        _ action: Action.Type,
        on routes: any RoutesBuilder,
        path: String,
        body: HTTPBodyStreamStrategy = .collect
    ) -> Route {
        post(action, on: routes, path: RoutePath(path), body: body)
    }

    @discardableResult
    public static func post<Action: UploadAction>(
        _ action: Action.Type,
        on routes: any RoutesBuilder,
        path: RoutePath,
        body: HTTPBodyStreamStrategy = .collect
    ) -> Route {
        routes.on(.post, path.vaporComponents, body: body) { req async throws -> Response in
            try SecurityRequestValidator.validateOrigin(req)
            let csrfToken = try await SecurityRequestValidator.csrfToken(
                from: req,
                source: req.application.securityConfiguration.csrf.uploadTokenSource
            )
            try SecurityRequestValidator.validateCSRF(
                req,
                suppliedCSRFToken: csrfToken
            )
            let params = try RouteParametersDecoder(req).decode(Action.Params.self)
            let input = try await req.content.decode(Action.Input.self)
            let requestValues = RequestValues(request: req, params: params, searchParams: NoSearchParams())
            return try await RequestContext.withValue(requestValues) {
                let result = try await Action().upload(UploadContext(request: req, params: params, input: input))
                return try await result.encodeResponse(for: req)
            }
        }
    }
}
