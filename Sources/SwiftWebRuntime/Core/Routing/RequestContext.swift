
public struct RequestValues: Sendable {
    public let request: Request
    public let security: RequestSecurityContext?

    private let paramsValue: any Sendable
    private let searchParamsValue: any Sendable

    public init<Params: Sendable, SearchParams: Sendable>(
        request: Request,
        params: Params,
        searchParams: SearchParams,
        security: RequestSecurityContext? = nil
    ) {
        self.request = request
        self.security = security ?? request.securityContext
        self.paramsValue = params
        self.searchParamsValue = searchParams
    }

    public func params<Params>(as type: Params.Type = Params.self) -> Params {
        guard let params = self.paramsValue as? Params else {
            preconditionFailure("Request context does not contain params of type \(Params.self)")
        }
        return params
    }

    public func searchParams<SearchParams>(as type: SearchParams.Type = SearchParams.self) -> SearchParams {
        guard let searchParams = self.searchParamsValue as? SearchParams else {
            preconditionFailure("Request context does not contain search params of type \(SearchParams.self)")
        }
        return searchParams
    }

    public var routeEnvironment: RouteEnvironment {
        RouteEnvironment(
            method: request.method.rawValue,
            url: request.url.string,
            path: request.url.path,
            params: paramsValue,
            searchParams: searchParamsValue
        )
    }
}

public enum RequestContext {
    @TaskLocal public static var current: RequestValues?

    public static var request: Request {
        guard let request = current?.request else {
            preconditionFailure("RequestContext.request was accessed outside a SwiftWeb page request")
        }
        return request
    }

    public static func withValue<Result: Sendable>(
        _ value: RequestValues,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await EnlargedStackContext.withValue(RequestContextPropagator(value: value)) {
            try await $current.withValue(value, operation: operation)
        }
    }
}

private struct RequestContextPropagator: EnlargedStackContextPropagator {
    let value: RequestValues

    func apply<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try RequestContext.$current.withValue(value, operation: operation)
    }
}
