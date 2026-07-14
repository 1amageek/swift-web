import HTTPTypes
import SwiftHTML
import SwiftWebHost

/// Wraps a routes builder so every handler registered through it runs with
/// the scene's environment established. This is how `.environment()` on a
/// scene reaches the pages, actions, and streams declared below it.
final class EnvironmentRoutesBuilder: RoutesBuilder {
    let base: any RoutesBuilder
    let environment: EnvironmentValues

    init(base: any RoutesBuilder, environment: EnvironmentValues) {
        self.base = base
        self.environment = environment
    }

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: BodyStreamStrategy,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        let environment = self.environment
        return base.on(method, path, body: body) { request in
            try await EnvironmentValues.withValue(environment) {
                try await handler(request)
            }
        }
    }

    @discardableResult
    func webSocket(
        _ path: [PathComponent],
        shouldUpgrade: @escaping @Sendable (Request) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (Request, any WebSocketChannel) async -> Void
    ) -> Route {
        let environment = self.environment
        return base.webSocket(
            path,
            shouldUpgrade: { request in
                try await EnvironmentValues.withValue(environment) {
                    try await shouldUpgrade(request)
                }
            },
            onUpgrade: { request, channel in
                await EnvironmentValues.withValue(environment) {
                    await onUpgrade(request, channel)
                }
            }
        )
    }

    func grouped(_ path: [PathComponent]) -> any RoutesBuilder {
        EnvironmentRoutesBuilder(base: base.grouped(path), environment: environment)
    }
}
