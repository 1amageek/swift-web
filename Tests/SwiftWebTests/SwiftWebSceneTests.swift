import HTTPTypes
import Synchronization
import SwiftHTML
import Testing
import Vapor
import VaporTesting

import SwiftWeb
import SwiftWebVapor

@Suite
struct SwiftWebSceneTests {
    @Test
    func appBodyMountsPagesInImplicitRootScene() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SceneFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/")

            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("Root Page"))
        }
    }

    @Test
    func pageGroupPrefixesChildPages() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SceneFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let index = try await application.testing().sendRequest(.get, "/admin")
            let users = try await application.testing().sendRequest(.get, "/admin/users")

            #expect(index.status == .ok)
            #expect(String(buffer: index.body).contains("Admin Index"))
            #expect(users.status == .ok)
            #expect(String(buffer: users.body).contains("Admin Users"))
        }
    }

    @Test
    func emptySceneRegistersNoRoutes() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(EmptySceneFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/")

            #expect(response.status == .notFound)
        }
    }

    @Test
    func conditionalSceneOnlyRegistersMountedBranch() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(ConditionalSceneFixtureApp(mountsPage: false))
                .configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/conditional")

            #expect(response.status == .notFound)
        }
    }

    @Test
    func conditionalSceneRegistersPageWhenBranchIsMounted() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(ConditionalSceneFixtureApp(mountsPage: true))
                .configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/conditional")

            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("Conditional Page"))
        }
    }

    @Test
    func nestedPageGroupsComposePathPrefixes() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(NestedGroupSceneFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/admin/settings/profile")

            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("Nested Profile"))
        }
    }

    @Test
    func pageGroupPrefixesPrimitiveEndpointScenes() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(GroupedRedirectSceneFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/legacy/old")

            #expect(response.status == .seeOther)
            #expect(response.headers[HTTPField.Name("Location")!] == "/new")
        }
    }

    @Test
    func appRunnerRunsShutdownHandlersOnceWhenConfigureFails() async throws {
        let shutdownCount = Mutex(0)

        do {
            try await AppRunner(
                SceneFixtureApp(),
                routeInstallers: [
                    { _ in
                        throw Abort(.internalServerError, reason: "Route installer failed")
                    },
                ],
                shutdownHandlers: [
                    {
                        shutdownCount.withLock { count in
                            count += 1
                        }
                    },
                ]
            ).run()
            Issue.record("AppRunner should fail when a route installer fails")
        } catch let abort as Abort {
            #expect(abort.status == .internalServerError)
        }

        #expect(shutdownCount.withLock { $0 } == 1)
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }
}

private struct SceneFixtureApp: App {
    var body: some Scene {
        SceneRootPage()

        PageGroup("admin") {
            SceneAdminIndexPage()
            SceneAdminUsersPage()
        }
    }
}

private struct EmptySceneFixtureApp: App {
    var body: some Scene {
        EmptyScene()
    }
}

private struct ConditionalSceneFixtureApp: App {
    let mountsPage: Bool

    init() {
        self.init(mountsPage: true)
    }

    init(mountsPage: Bool) {
        self.mountsPage = mountsPage
    }

    var body: some Scene {
        if mountsPage {
            SceneConditionalPage()
        }
    }
}

private struct NestedGroupSceneFixtureApp: App {
    var body: some Scene {
        PageGroup("admin") {
            PageGroup("settings") {
                SceneNestedProfilePage()
            }
        }
    }
}

private struct GroupedRedirectSceneFixtureApp: App {
    var body: some Scene {
        PageGroup("legacy") {
            Redirect("old", to: "/new")
        }
    }
}

@Page("/")
private struct SceneRootPage {
    func body() -> some HTML {
        main {
            h1 { "Root Page" }
        }
    }
}

@Page("/")
private struct SceneAdminIndexPage {
    func body() -> some HTML {
        main {
            h1 { "Admin Index" }
        }
    }
}

@Page("users")
private struct SceneAdminUsersPage {
    func body() -> some HTML {
        main {
            h1 { "Admin Users" }
        }
    }
}

@Page("/conditional")
private struct SceneConditionalPage {
    func body() -> some HTML {
        main {
            h1 { "Conditional Page" }
        }
    }
}

@Page("profile")
private struct SceneNestedProfilePage {
    func body() -> some HTML {
        main {
            h1 { "Nested Profile" }
        }
    }
}
