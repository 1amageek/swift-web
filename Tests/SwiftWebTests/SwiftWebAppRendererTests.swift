import HTTPTypes
import SwiftWeb
import Testing

@_spi(Hosting) @testable import SwiftWebCore
@_spi(Rendering) import SwiftWebCore

@Suite
struct SwiftWebAppRendererTests {
    @Test
    func renderingProducesRoutesAndRequestConfiguration() async throws {
        let serverConfiguration = ServerConfiguration(
            hostname: "renderer.test",
            port: 8443
        )

        let renderedApp = try await AppRenderer.render(
            RendererFixtureApp(),
            in: AppRenderingContext(serverConfiguration: serverConfiguration)
        )

        #expect(renderedApp.requestContext.serverConfiguration == serverConfiguration)
        #expect(
            renderedApp.routes.contains { route in
                route.method == .get
                    && route.path.map(String.init(describing:)) == ["health"]
            }
        )
    }

    @Test
    func renderingPropagatesSceneFailure() async {
        await #expect(throws: RendererFixtureError.self) {
            _ = try await AppRenderer.render(
                FailingRendererFixtureApp(),
                in: AppRenderingContext()
            )
        }
    }
}

private struct RendererFixtureApp: App {
    var body: some Scene {
        Endpoint("/health") { _ in
            Response(status: .ok)
        }
    }
}

private struct FailingRendererFixtureApp: App {
    var body: some Scene {
        FailingRendererFixtureScene()
    }
}

private struct FailingRendererFixtureScene: Scene, _PrimitiveScene {
    func _renderScene(in context: SceneRenderingContext) async throws {
        throw RendererFixtureError.expectedFailure
    }
}

private enum RendererFixtureError: Error {
    case expectedFailure
}
