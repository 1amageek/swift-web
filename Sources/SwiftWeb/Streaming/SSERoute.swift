import HTTPTypes
import Vapor

public protocol SSERoute: SendableMetatype {
    associatedtype SearchParams: Decodable & Sendable = NoSearchParams

    init()

    func events(_ context: SSEContext<SearchParams>) async throws -> AsyncThrowingStream<SSEEvent, any Error>
}

public enum SSERouteBuilder {
    @discardableResult
    public static func register<RouteType: SSERoute>(
        _ route: RouteType.Type,
        on routes: any RoutesBuilder,
        path: String
    ) -> Route {
        register(route, on: routes, path: RoutePath(path))
    }

    @discardableResult
    public static func register<RouteType: SSERoute>(
        _ route: RouteType.Type,
        on routes: any RoutesBuilder,
        path: RoutePath
    ) -> Route {
        routes.get(path.vaporComponents) { req async throws -> Response in
            let searchParams = try req.query.decode(RouteType.SearchParams.self)
            let requestValues = RequestValues(request: req, params: NoParams(), searchParams: searchParams)
            var configuredEnvironment = EnvironmentValues()
            configuredEnvironment.applyRequestValues(requestValues)
            let environment = configuredEnvironment
            let context = SSEContext(request: req, searchParams: searchParams)
            let headers: HTTPFields = [
                .contentType: "text/event-stream; charset=utf-8",
                .cacheControl: "no-cache",
            ]

            guard SwiftWebRuntime.streamsResponses else {
                return try await RequestContext.withValue(requestValues) {
                    let stream = try await RouteType().events(context)
                    let collected = StreamWriter.collecting(environment: environment)
                    for try await event in stream {
                        try await collected.writer.write(event.render())
                    }
                    return Response(headers: headers, body: .init(string: await collected.buffer.output()))
                }
            }

            return Response(
                headers: headers,
                body: .init(managedAsyncStream: { writer in
                    try await RequestContext.withValue(requestValues) {
                        let stream = try await RouteType().events(context)
                        let streamWriter = StreamWriter(writer, environment: environment)
                        for try await event in stream {
                            try await streamWriter.write(event.render())
                        }
                    }
                })
            )
        }
    }
}
