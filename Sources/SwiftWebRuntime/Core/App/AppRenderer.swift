import ActorSystemCore
import SwiftWebActors

/// Converts a declarative `App` into the routes, middleware, and request
/// context a host needs to serve it.
@_spi(Hosting)
public enum AppRenderer {
    public static func render<AppType: App>(
        _ app: AppType,
        in context: AppRenderingContext
    ) async throws -> RenderedApp {
        let actorSystem = app.actorSystem
        #if SWIFTWEB_ACTORS || hasFeature(Embedded)
        try actorSystem.installActorRouteBindings(context.actorRouteBindings)
        #endif
        let actorBindings = SwiftWebActorBindingScope(
            records: context.actorBindings,
            routeRecords: context.actorRouteBindings,
            actorSystem: actorSystem
        )
        #if SWIFTWEB_LEGACY_ACTORS
        let legacyActorSystem = app.legacyActorSystem
        let runtime = AppRuntime(
            serverConfiguration: context.serverConfiguration,
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem
        )
        let sceneContext = SceneRenderingContext.root(
            runtime,
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem,
            actorBindings: actorBindings,
            actorServiceBindings: context.actorServiceBindings
        )
        #else
        let runtime = AppRuntime(
            serverConfiguration: context.serverConfiguration,
            actorSystem: actorSystem
        )
        let sceneContext = SceneRenderingContext.root(
            runtime,
            actorSystem: actorSystem,
            actorBindings: actorBindings,
            actorServiceBindings: context.actorServiceBindings
        )
        #endif
        let security = context.developmentHooks.configureSecurity(app.security)
        runtime.requestContext.securityConfiguration = security

        var middlewares = Middlewares()
        security.installMiddleware(on: &middlewares)
        context.developmentHooks.installMiddlewares(&middlewares)
        context.developmentHooks.registerRoutes(runtime.routes)

        do {
            try await (context.clientRuntime ?? app.clientRuntime).install(in: runtime)
            try await SceneRenderer.render(
                app.body,
                in: sceneContext
            )
            #if SWIFTWEB_ACTORS
            if runtime.requiresActorSystem {
                try await actorSystem.actorHost.installAuthorization(
                    security.actors.authorization
                )
                try await actorSystem.actorHost.installActivationPolicy(
                    security.actors.activation
                )
            }
            #endif
            try await runtime.start()
        } catch {
            let termination = await runtime.requestShutdown()
            try await termination.wait()
            throw error
        }

        return RenderedApp(
            routes: runtime.routes.all,
            middlewares: middlewares,
            requestContext: runtime.requestContext,
            requestShutdown: {
                await runtime.requestShutdown()
            }
        )
    }
}
