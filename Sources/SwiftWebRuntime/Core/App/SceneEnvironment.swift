import SwiftHTML

extension Scene {
    /// Sets an environment value for the scenes in the hierarchy below.
    /// `ActorGroup` actors read it with `@Environment`, established around
    /// activation and every invocation:
    ///
    ///     ActorGroup {
    ///         SupportAgent(actorSystem: actorSystem)
    ///     }
    ///     .environment(\.model, claude)
    #if !hasFeature(Embedded)
    public func environment<Value: Sendable>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value> & Sendable,
        _ value: Value
    ) -> some Scene {
        _EnvironmentScene(content: self) { values in
            values[keyPath: keyPath] = value
        }
    }
    #endif

    /// Sets a type-keyed environment value, mirroring `HTML.environment(_:)`.
    public func environment<Value: Sendable>(_ value: Value) -> some Scene {
        _EnvironmentScene(content: self) { values in
            values[Value.self] = value
        }
    }

    /// Mutation-closure form of `environment(_:_:)` — the profile-neutral
    /// spelling (key-path literals cannot compile under Embedded Swift),
    /// mirroring `HTML.transformEnvironment(_:)`.
    public func transformEnvironment(
        _ transform: @escaping @Sendable (inout EnvironmentValues) -> Void
    ) -> some Scene {
        _EnvironmentScene(content: self, transform: transform)
    }
}

extension PageRoute {
    /// Sets an environment value for this page's rendering, mirroring the
    /// scene modifier so pages compose the same way scenes do.
    #if !hasFeature(Embedded)
    public func environment<Value: Sendable>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value> & Sendable,
        _ value: Value
    ) -> some Scene {
        PageRouteScene(self).environment(keyPath, value)
    }
    #endif

    public func environment<Value: Sendable>(_ value: Value) -> some Scene {
        PageRouteScene(self).environment(value)
    }

    public func transformEnvironment(
        _ transform: @escaping @Sendable (inout EnvironmentValues) -> Void
    ) -> some Scene {
        PageRouteScene(self).transformEnvironment(transform)
    }
}

struct _EnvironmentScene<Content: Scene>: Scene, _PrimitiveScene {
    let content: Content
    let transform: @Sendable (inout EnvironmentValues) -> Void

    func _makeScene(in context: _SceneContext) async throws {
        var environment = context.environment
        transform(&environment)
        // Carry the environment down the scene graph (ActorGroup, nested
        // modifiers) and establish it around every route handler registered
        // below, so page/action/stream rendering sees the same values.
        let modified = _SceneContext(
            application: context.application,
            routes: EnvironmentRoutesBuilder(base: context.routes, environment: environment),
            actorSystem: context.actorSystem,
            environment: environment,
            actorBindings: context.actorBindings
        )
        try await _SceneRenderer.make(content, in: modified)
    }
}
