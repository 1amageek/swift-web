#if SWIFTWEB_ACTORS || hasFeature(Embedded)
import ActorSystemCore
import SwiftWebActors

struct ActorReferenceScene<Content: Scene, ActorType: ActorSystemReference>:
    Scene,
    _PrimitiveScene
where ActorType.ActorSystem == WebActorSystem {
    private let content: Content
    private let identity: String

    init(content: Content, actorType: ActorType.Type, identity: String) {
        self.content = content
        self.identity = identity
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        context.runtime.requireActorSystem()
        #if SWIFTWEB_ACTORS
        try context.actorSystem.registerGeneratedBootstrapIfAvailable(
            for: ActorType.self
        )
        ActorFrameInvocationEndpoint.registerIfNeeded(
            in: context.runtime,
            actorSystem: context.actorSystem
        )
        #endif
        guard !identity.isEmpty else {
            throw SwiftWebActorServiceBindingError.emptyIdentity
        }
        let address = ActorAddress(
            type: ActorType.actorTypeDescriptor.id,
            identity: identity
        )
        let actor = try ActorType.resolve(
            id: address,
            using: context.actorSystem
        )
        let serviceRoutes = try context.actorServiceRoutes(for: address)
        if let hostRoute = serviceRoutes.host {
            try context.actorSystem.mergeActorRouteBindings([
                SwiftWebActorRouteBindingRecord(
                    actorID: address,
                    route: hostRoute
                )
            ])
        }
        let scope = context.actorBindings.adding(
            actor,
            clientRoute: serviceRoutes.client
        )
        let modified = context.replacing(
            routes: ActorBindingRoutesBuilder(
                base: context.routes,
                scope: scope
            ),
            environment: context.environment,
            actorBindings: scope
        )
        try await SwiftWebActorRenderContext.withValue(scope) {
            try await SceneRenderer.render(content, in: modified)
        }
    }
}
#endif
