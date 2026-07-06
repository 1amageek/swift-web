import HTTPTypes
import SwiftHTML
import Testing
import class Vapor.Application
import VaporTesting

import SwiftWeb
import SwiftWebVapor

@Suite
struct SwiftWebSessionTests {
    @Test
    func sessionReadDoesNotCreateCookie() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SessionFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/session")

            #expect(response.status == .ok)
            let body = String(buffer: response.body)
            #expect(body.contains("guest"))
            #expect(body.contains("none"))
            #expect(!hasSessionCookie(response))
        }
    }

    @Test
    func clearingMissingAuthenticationDoesNotCreateCookie() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SessionFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let response = try await application.testing().sendRequest(.get, "/session/clear")

            #expect(response.status == .ok)
            #expect(!hasSessionCookie(response))
        }
    }

    @Test
    func sessionPersistsValuesAcrossRequests() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SessionFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let login = try await application.testing().sendRequest(.get, "/session/login")
            let cookie = try sessionCookieHeader(from: login)

            var headers: HTTPFields = [:]
            headers[.cookie] = cookie
            let response = try await application.testing().sendRequest(.get, "/session", headers: headers)

            #expect(response.status == .ok)
            let body = String(buffer: response.body)
            #expect(body.contains("authenticated"))
            #expect(body.contains("user-1"))
            #expect(body.contains("custom-value"))
        }
    }

    @Test
    func sessionDestroyClearsPersistedValues() async throws {
        try await withApplication { application in
            let installation = try await AppRunner(SessionFixtureApp()).configure(application)
            defer {
                installation.shutdown()
            }

            let login = try await application.testing().sendRequest(.get, "/session/login")
            let cookie = try sessionCookieHeader(from: login)

            var headers: HTTPFields = [:]
            headers[.cookie] = cookie
            let logout = try await application.testing().sendRequest(.get, "/session/logout", headers: headers)

            #expect(logout.status == .ok)
            #expect(hasExpiredSessionCookie(logout))

            let response = try await application.testing().sendRequest(.get, "/session", headers: headers)

            #expect(response.status == .ok)
            let body = String(buffer: response.body)
            #expect(body.contains("guest"))
            #expect(body.contains("none"))
            #expect(body.contains("missing"))
        }
    }

    private func withApplication(
        _ body: (Vapor.Application) async throws -> Void
    ) async throws {
        let application = try await Vapor.Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }

    private func hasSessionCookie(_ response: TestingHTTPResponse) -> Bool {
        response.headers[values: .setCookie].contains { setCookie in
            setCookie.hasPrefix("swiftweb-session=")
        }
    }

    private func hasExpiredSessionCookie(_ response: TestingHTTPResponse) -> Bool {
        response.headers[values: .setCookie].contains { setCookie in
            setCookie.hasPrefix("swiftweb-session=;") && setCookie.contains("Expires=")
        }
    }

    private func sessionCookieHeader(from response: TestingHTTPResponse) throws -> String {
        for setCookie in response.headers[values: .setCookie] {
            guard let pair = setCookie.split(separator: ";", maxSplits: 1).first else {
                continue
            }
            if pair.hasPrefix("swiftweb-session=") {
                return String(pair)
            }
        }
        throw SwiftWebSessionTestError.missingSessionCookie
    }
}

private struct SessionFixtureApp: App {
    var body: some Scene {
        SessionReadPage()
        SessionLoginPage()
        SessionClearPage()
        SessionLogoutPage()
    }
}

@Page("/session")
private struct SessionReadPage {
    @Session var session

    func body() -> some HTML {
        main {
            p { session.isAuthenticated ? "authenticated" : "guest" }
            p { session.userID ?? "none" }
            p { session["custom"] ?? "missing" }
        }
    }
}

@Page("/session/login")
private struct SessionLoginPage {
    @Session var session

    func body() -> some HTML {
        session.authenticate(userID: "user-1")
        session["custom"] = "custom-value"
        return main {
            p { session.userID ?? "none" }
        }
    }
}

@Page("/session/clear")
private struct SessionClearPage {
    @Session var session

    func body() -> some HTML {
        session.clearAuthentication()
        return main {
            p { session.isAuthenticated ? "authenticated" : "guest" }
        }
    }
}

@Page("/session/logout")
private struct SessionLogoutPage {
    @Session var session

    func body() -> some HTML {
        session.destroy()
        return main {
            p { "logged-out" }
        }
    }
}

private enum SwiftWebSessionTestError: Error {
    case missingSessionCookie
}
