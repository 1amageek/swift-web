#if !hasFeature(Embedded)
// SSE/streaming routes decode Codable search params and stream
// over the native host; full profiles only.
import SwiftWebBrowserRuntime
import HTTPTypes

public protocol StreamingPage: SendableMetatype {
    associatedtype SearchParams: Decodable & Sendable = NoSearchParams

    init()

    func stream(_ context: SSEContext<SearchParams>, writer: StreamWriter) async throws
}

public enum StreamingPageRoute {
    @discardableResult
    public static func register<Page: StreamingPage>(
        _ page: Page.Type,
        on routes: any RoutesBuilder,
        path: String
    ) -> Route {
        register(page, on: routes, path: RoutePath(path))
    }

    @discardableResult
    public static func register<Page: StreamingPage>(
        _ page: Page.Type,
        on routes: any RoutesBuilder,
        path: RoutePath
    ) -> Route {
        routes.get(path.webComponents) { req async throws -> Response in
            let searchParams = try URLEncodedFormDecoder().decode(Page.SearchParams.self, from: req.url.query ?? "")
            let headers: HTTPFields = [.contentType: "text/html; charset=utf-8"]
            let requestValues = RequestValues(request: req, params: NoParams(), searchParams: searchParams)
            var configuredEnvironment = EnvironmentValues.swiftWebAmbient
            configuredEnvironment.applyRequestValues(requestValues)
            let environment = configuredEnvironment

            guard SwiftWebRuntime.streamsResponses else {
                let collected = StreamWriter.collecting(environment: environment)
                try await RequestContext.withValue(requestValues) {
                    try await Page().stream(
                        SSEContext(request: req, searchParams: searchParams),
                        writer: collected.writer
                    )
                }
                return Response(headers: headers, body: .init(string: await collected.buffer.output()))
            }

            return Response(
                headers: headers,
                body: .init(managedAsyncStream: { writer in
                    try await RequestContext.withValue(requestValues) {
                        try await Page().stream(
                            SSEContext(request: req, searchParams: searchParams),
                            writer: StreamWriter(writer, environment: environment)
                        )
                    }
                })
            )
        }
    }
}
#endif
