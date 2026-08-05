import SwiftHTML
import SwiftWebActors

public protocol Scene: SendableMetatype {
    associatedtype Body: Scene

    @SceneBuilder
    var body: Self.Body { get }

    /// Witness-based rendering hook used by the framework renderer.
    @_spi(Rendering)
    static func _renderScene(_ scene: Self, in context: SceneRenderingContext) async throws
}

extension Never: Scene {
    public typealias Body = Never
}

public extension Scene where Body == Never {
    var body: Never {
        fatalError("Primitive scenes do not expose body.")
    }
}

protocol _PrimitiveScene: Scene where Body == Never {
    func _renderScene(in context: SceneRenderingContext) async throws
}

extension Scene {
    /// Witness-based lowering (the SwiftUI `_makeView` pattern): the static
    /// requirement dispatches on the concrete type at compile time, replacing
    /// the existential downcast Embedded Swift cannot perform. Composite
    /// scenes recurse into `body`.
    @_spi(Rendering)
    public static func _renderScene(_ scene: Self, in context: SceneRenderingContext) async throws {
        try await SceneRenderer.render(scene.body, in: context)
    }
}

extension _PrimitiveScene {
    @_spi(Rendering)
    public static func _renderScene(_ scene: Self, in context: SceneRenderingContext) async throws {
        try await scene._renderScene(in: context)
    }
}

package enum SceneRenderer {
    package static func render<Content: Scene>(
        _ scene: Content,
        in context: SceneRenderingContext
    ) async throws {
        try await Content._renderScene(scene, in: context)
    }
}

@_spi(Rendering)
public struct SceneRenderingContext {
    package let runtime: AppRuntime
    package let routes: any RoutesBuilder
    package let actorSystem: WebActorSystem
    package let environment: EnvironmentValues
    package let actorBindings: SwiftWebActorBindingScope

    package init(
        runtime: AppRuntime,
        routes: any RoutesBuilder,
        actorSystem: WebActorSystem = .shared,
        environment: EnvironmentValues = EnvironmentValues(),
        actorBindings: SwiftWebActorBindingScope = .empty
    ) {
        self.runtime = runtime
        self.routes = routes
        self.actorSystem = actorSystem
        self.environment = environment
        self.actorBindings = actorBindings
    }

    package static func root(
        _ runtime: AppRuntime,
        actorSystem: WebActorSystem = .shared
    ) -> SceneRenderingContext {
        SceneRenderingContext(runtime: runtime, routes: runtime.routes, actorSystem: actorSystem)
    }

    package func grouped(_ path: String) -> SceneRenderingContext {
        grouped(RoutePath(path))
    }

    package func grouped(_ path: RoutePath) -> SceneRenderingContext {
        guard !path.components.isEmpty else {
            return self
        }
        return SceneRenderingContext(
            runtime: runtime,
            routes: routes.grouped(path.webComponents),
            actorSystem: actorSystem,
            environment: environment,
            actorBindings: actorBindings
        )
    }

    #if SWIFTWEB_ACTORS
    package func adding<ActorType: SwiftWebActorExporting>(_ actor: ActorType) -> SceneRenderingContext {
        SceneRenderingContext(
            runtime: runtime,
            routes: routes,
            actorSystem: actorSystem,
            environment: environment,
            actorBindings: actorBindings.adding(actor)
        )
    }
    #endif

    package func withEnvironment(_ environment: EnvironmentValues) -> SceneRenderingContext {
        SceneRenderingContext(
            runtime: runtime,
            routes: routes,
            actorSystem: actorSystem,
            environment: environment,
            actorBindings: actorBindings
        )
    }
}

public enum SwiftWebActorRenderContext {
    public static var currentScope: SwiftWebActorBindingScope {
        SwiftWebActorBindingContext.current ?? .empty
    }

    public static func withValue<Result>(
        _ value: SwiftWebActorBindingScope,
        operation: () throws -> Result
    ) rethrows -> Result {
        try EnlargedStackContext.withValue(SwiftWebActorRenderContextPropagator(scope: value)) {
            try SwiftWebActorBindingContext.withValue(value, operation: operation)
        }
    }

    public static func withValue<Result: Sendable>(
        _ value: SwiftWebActorBindingScope,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await EnlargedStackContext.withValue(SwiftWebActorRenderContextPropagator(scope: value)) {
            try await SwiftWebActorBindingContext.withValue(value, operation: operation)
        }
    }
}

private struct SwiftWebActorRenderContextPropagator: EnlargedStackContextPropagator {
    let scope: SwiftWebActorBindingScope

    func apply<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try SwiftWebActorBindingContext.withValue(scope, operation: operation)
    }
}
