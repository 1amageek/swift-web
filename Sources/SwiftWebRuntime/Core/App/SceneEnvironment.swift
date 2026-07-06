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
    public func environment<Value: Sendable>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value> & Sendable,
        _ value: Value
    ) -> some Scene {
        _EnvironmentScene(content: self) { values in
            values[keyPath: keyPath] = value
        }
    }

    /// Sets a type-keyed environment value, mirroring `HTML.environment(_:)`.
    public func environment<Value: Sendable>(_ value: Value) -> some Scene {
        _EnvironmentScene(content: self) { values in
            values[Value.self] = value
        }
    }
}

struct _EnvironmentScene<Content: Scene>: Scene, _PrimitiveScene {
    let content: Content
    let transform: @Sendable (inout EnvironmentValues) -> Void

    func _makeScene(in context: _SceneContext) async throws {
        var environment = context.environment
        transform(&environment)
        try await _SceneRenderer.make(content, in: context.withEnvironment(environment))
    }
}
