import Vapor

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

package enum _SceneRenderer {
    package static func make<Content: Scene>(
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

package struct _SceneContext {
    package let application: Application
    package let routes: any RoutesBuilder

    package init(application: Application, routes: any RoutesBuilder) {
        self.application = application
        self.routes = routes
    }

    package static func root(_ application: Application) -> _SceneContext {
        _SceneContext(application: application, routes: application)
    }

    package func grouped(_ path: String) -> _SceneContext {
        grouped(RoutePath(path))
    }

    package func grouped(_ path: RoutePath) -> _SceneContext {
        guard !path.components.isEmpty else {
            return self
        }
        return _SceneContext(application: application, routes: routes.grouped(path.vaporComponents))
    }
}
