import HTTPTypes

/// A scene that serves a non-HTML resource (sitemap.xml, robots.txt, feeds)
/// from a handler. The handler returns the response body as a string; the
/// scene wraps it with the given content type. Available on every profile,
/// including Embedded.
public struct Endpoint: Scene, Sendable, _PrimitiveScene {
    private let path: RoutePath
    private let contentType: String
    private let handler: @Sendable (Request) async throws -> String

    public init(
        _ path: String,
        contentType: String,
        handler: @escaping @Sendable (Request) async throws -> String
    ) {
        self.path = RoutePath(path)
        self.contentType = contentType
        self.handler = handler
    }

    func _makeScene(in context: _SceneContext) async throws {
        let contentType = self.contentType
        let handler = self.handler
        context.routes.get(path.webComponents) { request in
            let body = try await handler(request)
            var headers = HTTPFields()
            headers[.contentType] = contentType
            return Response(status: .ok, headers: headers, body: .init(string: body))
        }
    }
}
