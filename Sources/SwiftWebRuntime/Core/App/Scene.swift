import SwiftHTML
import SwiftWebActors

public protocol Scene {
    associatedtype Body: Scene

    @SceneBuilder
    var body: Self.Body { get }

    /// Witness-based lowering hook; see the `Scene` extension default.
    static func _lowerScene(_ scene: Self, in context: _SceneContext) async throws
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
    func _makeScene(in context: _SceneContext) async throws
}

extension Scene {
    /// Witness-based lowering (the SwiftUI `_makeView` pattern): the static
    /// requirement dispatches on the concrete type at compile time, replacing
    /// the existential downcast Embedded Swift cannot perform. Composite
    /// scenes recurse into `body`.
    public static func _lowerScene(_ scene: Self, in context: _SceneContext) async throws {
        try await _SceneRenderer.make(scene.body, in: context)
    }
}

extension _PrimitiveScene {
    public static func _lowerScene(_ scene: Self, in context: _SceneContext) async throws {
        try await scene._makeScene(in: context)
    }
}

public enum _SceneRenderer {
    public static func make<Content: Scene>(
        _ scene: Content,
        in context: _SceneContext
    ) async throws {
        try await Content._lowerScene(scene, in: context)
    }
}

public struct _SceneContext {
    public let application: Application
    public let routes: any RoutesBuilder
    public let actorSystem: WebActorSystem
    public let environment: EnvironmentValues
    package let actorBindings: SwiftWebActorBindingScope

    public init(
        application: Application,
        routes: any RoutesBuilder,
        actorSystem: WebActorSystem = .shared,
        environment: EnvironmentValues = EnvironmentValues(),
        actorBindings: SwiftWebActorBindingScope = .empty
    ) {
        self.application = application
        self.routes = routes
        self.actorSystem = actorSystem
        self.environment = environment
        self.actorBindings = actorBindings
    }

    public static func root(
        _ application: Application,
        actorSystem: WebActorSystem = .shared
    ) -> _SceneContext {
        _SceneContext(application: application, routes: application.routes, actorSystem: actorSystem)
    }

    package func grouped(_ path: String) -> _SceneContext {
        grouped(RoutePath(path))
    }

    package func grouped(_ path: RoutePath) -> _SceneContext {
        guard !path.components.isEmpty else {
            return self
        }
        return _SceneContext(
            application: application,
            routes: routes.grouped(path.webComponents),
            actorSystem: actorSystem,
            environment: environment,
            actorBindings: actorBindings
        )
    }

    #if SWIFTWEB_ACTORS
    package func adding<ActorType: SwiftWebActorExporting>(_ actor: ActorType) -> _SceneContext {
        _SceneContext(
            application: application,
            routes: routes,
            actorSystem: actorSystem,
            environment: environment,
            actorBindings: actorBindings.adding(actor)
        )
    }
    #endif

    package func withEnvironment(_ environment: EnvironmentValues) -> _SceneContext {
        _SceneContext(
            application: application,
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
