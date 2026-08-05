import SwiftHTML
import SwiftWeb
import Testing

@_spi(Hosting) @testable import SwiftWebCore

@Suite
struct SceneEnvironmentTests {
    @Test
    func sceneEnvironmentReachesPageRendering() async throws {
        let renderedApp = try await AppRenderer.render(
            SceneEnvironmentFixture(),
            in: AppRenderingContext()
        )

        let route = try #require(
            renderedApp.routes.first { route in
                route.method == .get && route.path.map(String.init(describing:)) == ["env"]
            }
        )
        guard case .http(let handler) = route.handler else {
            Issue.record("Page route should be an HTTP route")
            return
        }

        let response = try await handler(Request(renderedApp: renderedApp, path: "/env"))
        let html = try #require(response.body.string)
        #expect(html.contains("scene-injected"))
    }

    @Test
    func pagesOutsideTheModifierSeeTheDefault() async throws {
        let renderedApp = try await AppRenderer.render(
            SceneEnvironmentDefaultFixture(),
            in: AppRenderingContext()
        )

        let route = try #require(
            renderedApp.routes.first { route in
                route.method == .get && route.path.map(String.init(describing:)) == ["env"]
            }
        )
        guard case .http(let handler) = route.handler else {
            Issue.record("Page route should be an HTTP route")
            return
        }

        let response = try await handler(Request(renderedApp: renderedApp, path: "/env"))
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

    var document: some HTMLDocument {
        PageDocument(title: "Environment") {
            main {
                p { greeting }
            }
        }
    }
}

private struct SceneEnvironmentFixture: App {
    var body: some Scene {
        SceneEnvironmentPage()
            .environment(\.sceneGreeting, "scene-injected")
    }
}

private struct SceneEnvironmentDefaultFixture: App {
    @SceneBuilder var body: some Scene {
        SceneEnvironmentPage()
    }
}
