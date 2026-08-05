@_spi(Hosting) import SwiftWebHost

/// The immutable result a host receives after SwiftWeb renders an `App`.
@_spi(Hosting)
public struct RenderedApp: Sendable {
    public let routes: [Route]
    public let middlewares: Middlewares
    public let requestContext: RequestRuntimeContext

    package init(
        routes: [Route],
        middlewares: Middlewares,
        requestContext: RequestRuntimeContext
    ) {
        self.routes = routes
        self.middlewares = middlewares
        self.requestContext = requestContext
    }
}
