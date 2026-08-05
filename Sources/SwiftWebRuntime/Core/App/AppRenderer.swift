/// Converts a declarative `App` into the routes, middleware, and request
/// context a host needs to serve it.
@_spi(Hosting)
public enum AppRenderer {
    public static func render<AppType: App>(
        _ app: AppType,
        in context: AppRenderingContext
    ) async throws -> RenderedApp {
        let runtime = AppRuntime(
            serverConfiguration: context.serverConfiguration
        )
        let security = context.developmentHooks.configureSecurity(app.security)
        runtime.requestContext.securityConfiguration = security

        var middlewares = Middlewares()
        security.installMiddleware(on: &middlewares)
        context.developmentHooks.installMiddlewares(&middlewares)
        context.developmentHooks.registerRoutes(runtime.routes)

        try await (context.clientRuntime ?? app.clientRuntime).install(in: runtime)
        try await SceneRenderer.render(
            app.body,
            in: SceneRenderingContext.root(
                runtime,
                actorSystem: app.actorSystem
            )
        )

        return RenderedApp(
            routes: runtime.routes.all,
            middlewares: middlewares,
            requestContext: runtime.requestContext
        )
    }
}
