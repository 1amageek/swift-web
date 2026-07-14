
public struct RouteEnvironment: Sendable {
    public let method: String
    public let url: String
    public let path: String

    private let paramsBox: any AnyRuntimeBox
    private let searchParamsBox: any AnyRuntimeBox

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
        self.paramsBox = RuntimeBox(params)
        self.searchParamsBox = RuntimeBox(searchParams)
    }

    package init(
        method: String,
        url: String,
        path: String,
        paramsBox: any AnyRuntimeBox,
        searchParamsBox: any AnyRuntimeBox
    ) {
        self.method = method
        self.url = url
        self.path = path
        self.paramsBox = paramsBox
        self.searchParamsBox = searchParamsBox
    }

    public func params<Params: Sendable>(as type: Params.Type = Params.self) -> Params {
        guard let params = unboxRuntimeValue(paramsBox, as: Params.self) else {
            preconditionFailure("Route environment does not contain params of type \(RuntimeTypeLabel.of(Params.self))")
        }
        return params
    }

    public func searchParams<SearchParams: Sendable>(as type: SearchParams.Type = SearchParams.self) -> SearchParams {
        guard let searchParams = unboxRuntimeValue(searchParamsBox, as: SearchParams.self) else {
            preconditionFailure("Route environment does not contain search params of type \(RuntimeTypeLabel.of(SearchParams.self))")
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

    /// The environment established by enclosing scene `.environment()`
    /// modifiers, empty outside any.
    static var swiftWebAmbient: EnvironmentValues {
        EnvironmentValues.current
    }

    static var swiftWebCurrent: EnvironmentValues {
        // Seed with the scene environment; request-derived values win.
        var environment = swiftWebAmbient
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
