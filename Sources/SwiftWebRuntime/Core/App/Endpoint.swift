import HTTPTypes

/// A scene that serves a non-HTML resource (sitemap.xml, robots.txt, feeds,
/// icons) from a handler. Available on every profile, including Embedded.
///
/// Two forms cover the range of non-HTML resources:
/// - The **string form** wraps a text body with a content type and an
///   optional ``CachePolicy`` — deterministic resources like sitemaps
///   should declare the same cache lifetimes as the pages they index, or
///   every crawl re-renders them.
/// - The **response form** returns a full `Response`, for anything beyond a
///   200 text body: binary bodies (`Response.Body(bytes:)`), non-200
///   statuses, and custom headers (`ETag`, `Content-Disposition`, …) are
///   the handler's to compose.
///
/// Endpoints register as GET routes. A thrown error propagates to the
/// application's error handling (a 500 by default) — it is never swallowed.
public struct Endpoint: Scene, Sendable, _PrimitiveScene {
    private let path: RoutePath
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
    ///   - path: The GET route to register.
    ///   - handler: Produces the complete response — status, headers, and
    ///     body — for one request.
    public init(
        _ path: String,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) {
        self.path = RoutePath(path)
        self.handler = handler
    }

    func _makeScene(in context: _SceneContext) async throws {
        let handler = self.handler
        context.routes.get(path.webComponents) { request in
            try await handler(request)
        }
    }
}
