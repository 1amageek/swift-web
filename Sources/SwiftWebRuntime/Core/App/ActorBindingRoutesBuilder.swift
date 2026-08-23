import HTTPTypes
import SwiftWebActors
import SwiftWebHost

/// Establishes the actor binding scope for every handler registered below an
/// `.actor(...)` modifier, including non-page endpoints and WebSockets.
final class ActorBindingRoutesBuilder: RoutesBuilder {
    private let base: any RoutesBuilder
    private let scope: SwiftWebActorBindingScope

    init(base: any RoutesBuilder, scope: SwiftWebActorBindingScope) {
        self.base = base
        self.scope = scope
    }

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: BodyStreamStrategy,
        use handler: @escaping @Sendable (Request) async throws -> Response
    ) -> Route {
        let scope = self.scope
        return base.on(method, path, body: body) { request in
            try await SwiftWebActorRenderContext.withValue(scope) {
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
        let scope = self.scope
        return base.webSocket(
            path,
            shouldUpgrade: { request in
                try await SwiftWebActorRenderContext.withValue(scope) {
                    try await shouldUpgrade(request)
                }
            },
            onUpgrade: { request, channel in
                await SwiftWebActorRenderContext.withValue(scope) {
                    await onUpgrade(request, channel)
                }
            }
        )
    }

    func grouped(_ path: [PathComponent]) -> any RoutesBuilder {
        ActorBindingRoutesBuilder(base: base.grouped(path), scope: scope)
    }
}
