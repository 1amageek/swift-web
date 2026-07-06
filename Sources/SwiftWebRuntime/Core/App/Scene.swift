import SwiftHTML
import SwiftWebActors

public protocol Scene {
    associatedtype Body: Scene

    @SceneBuilder
    var body: Self.Body { get }
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

public enum _SceneRenderer {
    public static func make<Content: Scene>(
        _ scene: Content,
        in context: _SceneContext
    ) async throws {
        if let primitive = scene as? any _PrimitiveScene {
            try await primitive._makeScene(in: context)
        } else {
            try await make(scene.body, in: context)
        }
    }
}

public struct _SceneContext {
    public let application: Application
    public let routes: any RoutesBuilder
    public let actorSystem: WebActorSystem
    package let actorBindings: SwiftWebActorBindingScope

    public init(
        application: Application,
        routes: any RoutesBuilder,
        actorSystem: WebActorSystem = .shared,
        actorBindings: SwiftWebActorBindingScope = .empty
    ) {
        self.application = application
        self.routes = routes
        self.actorSystem = actorSystem
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
            actorBindings: actorBindings
        )
    }

    package func adding<ActorType: SwiftWebActorExporting>(_ actor: ActorType) -> _SceneContext {
        _SceneContext(
            application: application,
            routes: routes,
            actorSystem: actorSystem,
            actorBindings: actorBindings.adding(actor)
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
