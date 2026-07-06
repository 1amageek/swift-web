import HTTPTypes
import SwiftHTML
import SwiftWebHostKit

/// Wraps a routes builder so every handler registered through it runs with
/// the scene's environment established. This is how `.environment()` on a
/// scene reaches the pages, actions, and streams declared below it.
struct EnvironmentRoutesBuilder: WebRoutesBuilder {
    let base: any WebRoutesBuilder
    let environment: EnvironmentValues

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [WebPathComponent],
        body: WebBodyStreamStrategy,
        use handler: @escaping @Sendable (WebRequest) async throws -> WebResponse
    ) -> WebRoute {
        let environment = self.environment
        return base.on(method, path, body: body) { request in
            try await EnvironmentValues.withValue(environment) {
                try await handler(request)
            }
        }
    }

    @discardableResult
    func webSocket(
        _ path: [WebPathComponent],
        shouldUpgrade: @escaping @Sendable (WebRequest) async throws -> HTTPFields?,
        onUpgrade: @escaping @Sendable (WebRequest, any WebSocketChannel) async -> Void
    ) -> WebRoute {
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

    func grouped(_ path: [WebPathComponent]) -> any WebRoutesBuilder {
        EnvironmentRoutesBuilder(base: base.grouped(path), environment: environment)
    }
}
