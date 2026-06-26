import Vapor

public struct RouteEnvironment: Sendable {
    public let method: String
    public let url: String
    public let path: String

    private let paramsValue: any Sendable
    private let searchParamsValue: any Sendable

    public init<Params: Sendable, SearchParams: Sendable>(
        method: String,
        url: String,
        path: String,
        params: Params,
        searchParams: SearchParams
    ) {
        self.method = method
        self.url = url
        self.path = path
        self.paramsValue = params
        self.searchParamsValue = searchParams
    }

    public func params<Params>(as type: Params.Type = Params.self) -> Params {
        guard let params = paramsValue as? Params else {
            preconditionFailure("Route environment does not contain params of type \(Params.self)")
        }
        return params
    }

    public func searchParams<SearchParams>(as type: SearchParams.Type = SearchParams.self) -> SearchParams {
        guard let searchParams = searchParamsValue as? SearchParams else {
            preconditionFailure("Route environment does not contain search params of type \(SearchParams.self)")
        }
        return searchParams
    }

    static var empty: RouteEnvironment {
        RouteEnvironment(
            method: "GET",
            url: "/",
            path: "/",
            params: NoParams(),
            searchParams: NoSearchParams()
        )
    }
}

private struct RouteEnvironmentKey: EnvironmentKey {
    static let defaultValue = RouteEnvironment.empty
}

private struct AssetBasePathEnvironmentKey: EnvironmentKey {
    static let defaultValue = ""
}

private struct CSRFTokenEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct CSPNonceEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    public var route: RouteEnvironment {
        get { self[RouteEnvironmentKey.self] }
        set { self[RouteEnvironmentKey.self] = newValue }
    }

    public var requestMethod: String {
        route.method
    }

    public var requestURL: String {
        route.url
    }

    public var requestPath: String {
        route.path
    }

    public var assetBasePath: String {
        get { self[AssetBasePathEnvironmentKey.self] }
        set { self[AssetBasePathEnvironmentKey.self] = newValue }
    }

    public var csrfToken: String? {
        get { self[CSRFTokenEnvironmentKey.self] }
        set { self[CSRFTokenEnvironmentKey.self] = newValue }
    }

    public var cspNonce: String? {
        get { self[CSPNonceEnvironmentKey.self] }
        set { self[CSPNonceEnvironmentKey.self] = newValue }
    }

    static var swiftWebCurrent: EnvironmentValues {
        var environment = EnvironmentValues()
        if let context = RequestContext.current {
            environment.route = context.routeEnvironment
            environment.csrfToken = context.security?.csrfToken
            environment.cspNonce = context.security?.cspNonce
            if let csrfToken = context.security?.csrfToken,
               let csrfFieldName = context.security?.csrfFieldName {
                environment.actionHiddenFields = [
                    ActionField(csrfFieldName, csrfToken),
                ]
            }
        }
        return environment
    }

    mutating func applyRequestValues(_ values: RequestValues) {
        route = values.routeEnvironment
        csrfToken = values.security?.csrfToken
        cspNonce = values.security?.cspNonce
        if let csrfToken = values.security?.csrfToken,
           let csrfFieldName = values.security?.csrfFieldName {
            actionHiddenFields = [
                ActionField(csrfFieldName, csrfToken),
            ]
        }
    }
}
