import HTTPTypes

/// The authentication stance of an ``Endpoint`` route.
///
/// State-changing requests from the app's own pages carry the app's CSRF
/// token; requests from external services carry no session, origin, or
/// token and authenticate by their own contract (typically a signature
/// over the raw body). The stance decides which contract the framework
/// enforces before the handler runs.
///
/// Modeled as a closed set behind static properties (private storage enum)
/// so new stances can be added without breaking downstream code.
public struct EndpointSecurity: Equatable, Sendable {
    private enum Stance: Equatable, Sendable {
        case session
        case external
    }

    private let stance: Stance

    /// The endpoint is called by the app's own pages (fetch/XHR). For
    /// methods the app's ``CSRFPolicy`` protects, the framework validates
    /// the request origin and the CSRF token (header against token cookie)
    /// before the handler runs — the same contract form actions and actor
    /// invocations enforce. For methods the policy does not protect (GET
    /// under the default policy) this validates nothing.
    public static let session = EndpointSecurity(stance: .session)

    /// The endpoint is called by external services (payment webhooks,
    /// service-to-service callbacks) that have no browser session. No
    /// origin or CSRF validation runs; the handler owns authentication —
    /// verify a signature over ``Request/collectedBody()`` before trusting
    /// the payload.
    public static let external = EndpointSecurity(stance: .external)

    var validatesStateChangingRequests: Bool {
        stance == .session
    }
}

/// A scene that serves a non-HTML resource from a handler. Available on
/// every profile, including Embedded.
///
/// Two forms cover the range of non-HTML resources:
/// - The **string form** wraps a text body with a content type and an
///   optional ``CachePolicy`` — deterministic resources like sitemaps
///   should declare the same cache lifetimes as the pages they index, or
///   every crawl re-renders them. String-form endpoints register as GET
///   routes.
/// - The **response form** returns a full `Response`, for anything beyond a
///   200 text body: binary bodies (`Response.Body(bytes:)`), non-200
///   statuses, and custom headers (`ETag`, `Content-Disposition`, …) are
///   the handler's to compose. The response form also chooses the HTTP
///   method and the ``EndpointSecurity`` stance, which is how an app
///   exposes a POST JSON API to its own pages (`.session`, the default)
///   or a webhook to an external service (`.external`).
///
/// A thrown error propagates to the application's error handling — an
/// `Abort` becomes its status, anything else a 500 — it is never
/// swallowed. Webhook retry semantics can rely on a thrown error
/// producing a non-2xx response.
public struct Endpoint: Scene, Sendable, _PrimitiveScene {
    private let path: RoutePath
    private let method: HTTPRequest.Method
    private let security: EndpointSecurity
    private let handler: @Sendable (Request) async throws -> Response

    /// Serves a text resource with the given content type.
    ///
    /// - Parameters:
    ///   - path: The GET route to register.
    ///   - contentType: The `Content-Type` field value for every response.
    ///   - cache: The caching contract, emitted as `Cache-Control`.
    ///     Defaults to ``CachePolicy/none`` (no header).
    ///   - handler: Produces the response body for one request.
    public init(
        _ path: String,
        contentType: String,
        cache: CachePolicy = .none,
        handler: @escaping @Sendable (Request) async throws -> String
    ) {
        self.path = RoutePath(path)
        self.method = .get
        self.security = .session
        self.handler = { request in
            let body = try await handler(request)
            var headers = HTTPFields()
            headers[.contentType] = contentType
            let cacheControl = cache.headerValue
            if !cacheControl.isEmpty {
                headers[.cacheControl] = cacheControl
            }
            return Response(status: .ok, headers: headers, body: .init(string: body))
        }
    }

    /// Serves the handler's `Response` as-is.
    ///
    /// - Parameters:
    ///   - path: The route to register.
    ///   - method: The HTTP method to match. Defaults to `.get`, which
    ///     preserves the resource-serving contract; `.post` (and other
    ///     state-changing methods) turn the endpoint into an API route.
    ///   - security: The authentication stance. ``EndpointSecurity/session``
    ///     (the default) enforces the app's state-changing request policy;
    ///     ``EndpointSecurity/external`` hands authentication to the
    ///     handler, for callers like payment webhooks that sign the raw
    ///     body instead of holding a session.
    ///   - handler: Produces the complete response — status, headers, and
    ///     body — for one request. The raw request bytes are available via
    ///     ``Request/collectedBody()``.
    public init(
        _ path: String,
        method: HTTPRequest.Method = .get,
        security: EndpointSecurity = .session,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) {
        self.path = RoutePath(path)
        self.method = method
        self.security = security
        self.handler = handler
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        let handler = self.handler
        let security = self.security
        context.routes.on(method, path.webComponents) { request in
            if security.validatesStateChangingRequests {
                try SecurityRequestValidator.validateStateChangingRequest(request)
            }
            return try await handler(request)
        }
    }
}
