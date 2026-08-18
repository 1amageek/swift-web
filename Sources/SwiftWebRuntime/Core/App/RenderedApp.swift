import ActorSystemCore
@_spi(Hosting) import SwiftWebHost

/// The immutable result a host receives after SwiftWeb renders an `App`.
@_spi(Hosting)
public struct RenderedApp: Sendable {
    public let routes: [Route]
    public let middlewares: Middlewares
    public let requestContext: RequestRuntimeContext
    private let requestShutdownValue: @Sendable () async -> ActorSystemTermination

    package init(
        routes: [Route],
        middlewares: Middlewares,
        requestContext: RequestRuntimeContext,
        requestShutdown: @escaping @Sendable () async -> ActorSystemTermination
    ) {
        self.routes = routes
        self.middlewares = middlewares
        self.requestContext = requestContext
        self.requestShutdownValue = requestShutdown
    }

    public func requestShutdown() async -> ActorSystemTermination {
        await requestShutdownValue()
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }
}
