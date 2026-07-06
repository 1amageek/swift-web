import SwiftHTML
import SwiftWeb
import Testing

@testable import SwiftWebCore

@Suite
struct SceneEnvironmentTests {
    @Test
    func sceneEnvironmentReachesPageRendering() async throws {
        let application = TestWebApplication()
        try await _SceneRenderer.make(
            SceneEnvironmentFixture().scenes,
            in: _SceneContext(application: application, routes: application.routes)
        )

        let route = try #require(
            application.collectedRoutes.first { route in
                route.method == .get && route.path.map(String.init(describing:)) == ["env"]
            }
        )
        guard case .http(let handler) = route.handler else {
            Issue.record("Page route should be an HTTP route")
            return
        }

        let response = try await handler(WebRequest(application: application, path: "/env"))
        let html = try #require(response.body.string)
        #expect(html.contains("scene-injected"))
    }

    @Test
    func pagesOutsideTheModifierSeeTheDefault() async throws {
        let application = TestWebApplication()
        try await _SceneRenderer.make(
            SceneEnvironmentDefaultFixture().scenes,
            in: _SceneContext(application: application, routes: application.routes)
        )

        let route = try #require(
            application.collectedRoutes.first { route in
                route.method == .get && route.path.map(String.init(describing:)) == ["env"]
            }
        )
        guard case .http(let handler) = route.handler else {
            Issue.record("Page route should be an HTTP route")
            return
        }

        let response = try await handler(WebRequest(application: application, path: "/env"))
        let html = try #require(response.body.string)
        #expect(html.contains("unset-greeting"))
    }
}

// MARK: - Fixtures

private struct SceneGreetingKey: EnvironmentKey {
    static let defaultValue = "unset-greeting"
}

extension EnvironmentValues {
    fileprivate var sceneGreeting: String {
        get { self[SceneGreetingKey.self] }
        set { self[SceneGreetingKey.self] = newValue }
    }
}

@Page("/env")
private struct SceneEnvironmentPage {
    @Environment(\.sceneGreeting) private var greeting

    func body() -> some HTML {
        main {
            p { greeting }
        }
    }
}

private struct SceneEnvironmentFixture {
    var scenes: some Scene {
        SceneEnvironmentPage()
            .environment(\.sceneGreeting, "scene-injected")
    }
}

private struct SceneEnvironmentDefaultFixture {
    @SceneBuilder var scenes: some Scene {
        SceneEnvironmentPage()
    }
}
