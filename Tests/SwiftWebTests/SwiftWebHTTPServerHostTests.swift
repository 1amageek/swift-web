import Foundation
import HTTPTypes
import Logging
import SwiftHTML
import SwiftWeb
import SwiftWebHTTPServerHost
import Testing

@Suite
struct SwiftWebHTTPServerHostTests {
    @Test
    func servesPageWithSecurityHeadersAndCSRFCookie() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/")!)
            let http = try #require(response as? HTTPURLResponse)

            #expect(http.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self).contains("Host Root"))
            #expect(http.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff")
            let setCookie = try #require(http.value(forHTTPHeaderField: "Set-Cookie"))
            #expect(setCookie.contains("csrf_token="))
        }
    }

    @Test
    func decodesRouteParametersAndRejectsInvalidOnes() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (_, ok) = try await client.data(from: URL(string: "\(base)/items/42")!)
            #expect((ok as? HTTPURLResponse)?.statusCode == 200)

            let (_, invalid) = try await client.data(from: URL(string: "\(base)/items/not-a-number")!)
            #expect((invalid as? HTTPURLResponse)?.statusCode == 400)
        }
    }

    @Test
    func decodesSearchParamsFromQueryString() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, ok) = try await client.data(from: URL(string: "\(base)/search?q=hello+world")!)
            #expect((ok as? HTTPURLResponse)?.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self).contains("hello world"))

            let (_, missing) = try await client.data(from: URL(string: "\(base)/search")!)
            #expect((missing as? HTTPURLResponse)?.statusCode == 400)
        }
    }

    @Test
    func unmatchedRouteReturnsDecoratedNotFound() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/missing")!)
            let http = try #require(response as? HTTPURLResponse)

            #expect(http.statusCode == 404)
            #expect(http.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff")
            #expect(String(decoding: data, as: UTF8.self).contains("\"error\":true"))
        }
    }

    @Test
    func sessionIsCookieBackedAndReadDoesNotCreateOne() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            // Reading the session must not set a session cookie.
            let (readData, readResponse) = try await client.data(from: URL(string: "\(base)/session")!)
            let readHTTP = try #require(readResponse as? HTTPURLResponse)
            #expect(String(decoding: readData, as: UTF8.self).contains("guest"))
            let readCookie = readHTTP.value(forHTTPHeaderField: "Set-Cookie") ?? ""
            #expect(!readCookie.contains("swiftweb-session="))

            // Logging in sets the cookie; sending it back authenticates.
            let csrfCookie = try #require(readCookie.split(separator: ";").first.map(String.init))
            var login = URLRequest(url: URL(string: "\(base)/session/login")!)
            login.setValue(csrfCookie, forHTTPHeaderField: "Cookie")
            let (_, loginResponse) = try await client.data(for: login)
            let loginHTTP = try #require(loginResponse as? HTTPURLResponse)
            let sessionSetCookie = try #require(loginHTTP.value(forHTTPHeaderField: "Set-Cookie"))
            #expect(sessionSetCookie.contains("swiftweb-session="))
            let sessionCookie = try #require(sessionSetCookie.split(separator: ";").first.map(String.init))

            var authenticated = URLRequest(url: URL(string: "\(base)/session")!)
            authenticated.setValue("\(csrfCookie); \(sessionCookie)", forHTTPHeaderField: "Cookie")
            let (authData, _) = try await client.data(for: authenticated)
            #expect(String(decoding: authData, as: UTF8.self).contains("authenticated"))
        }
    }

    @Test
    func formActionRequiresCSRFAndDecodesFormBody() async throws {
        let installers: [(Application) async throws -> Void] = [
            { application in
                RouteAction.post(HostEchoFormAction.self, on: application.routes, path: "/submit")
            },
        ]
        try await withHost(HostFixtureApp(), routeInstallers: installers) { client, base in
            let (_, pageResponse) = try await client.data(from: URL(string: "\(base)/")!)
            let pageHTTP = try #require(pageResponse as? HTTPURLResponse)
            let setCookie = try #require(pageHTTP.value(forHTTPHeaderField: "Set-Cookie"))
            let csrfCookie = try #require(setCookie.split(separator: ";").first.map(String.init))
            let token = try #require(csrfCookie.split(separator: "=", maxSplits: 1).last.map(String.init))

            var missingToken = URLRequest(url: URL(string: "\(base)/submit")!)
            missingToken.httpMethod = "POST"
            missingToken.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            missingToken.setValue(csrfCookie, forHTTPHeaderField: "Cookie")
            missingToken.httpBody = Data("message=hi".utf8)
            let (_, forbidden) = try await client.data(for: missingToken)
            #expect((forbidden as? HTTPURLResponse)?.statusCode == 403)

            var valid = URLRequest(url: URL(string: "\(base)/submit")!)
            valid.httpMethod = "POST"
            valid.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            valid.setValue(csrfCookie, forHTTPHeaderField: "Cookie")
            valid.httpBody = Data("_csrf=\(token)&message=hi+host".utf8)
            let (data, ok) = try await client.data(for: valid)
            #expect((ok as? HTTPURLResponse)?.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self) == "message:hi host")
        }
    }

    @Test
    func servesSSEEndpoint() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/events")!)
            let http = try #require(response as? HTTPURLResponse)

            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true)
            #expect(String(decoding: data, as: UTF8.self).contains("data: tick-1"))
        }
    }

    // MARK: - Harness

    private enum HostTestError: Error {
        case serverNeverBecameReady
    }

    private func withHost<Definition: App>(
        _ app: Definition,
        routeInstallers: [(Application) async throws -> Void] = [],
        _ body: (URLSession, String) async throws -> Void
    ) async throws {
        for _ in 0..<5 {
            let port = Int.random(in: 20_000..<60_000)
            let runner = HTTPServerAppRunner(
                app,
                hostname: "127.0.0.1",
                port: port,
                routeInstallers: routeInstallers
            )
            let installation = try await runner.configure(logger: Logger(label: "swiftweb.tests.host"))
            let serveTask = Task {
                try await installation.serve()
            }
            let client = Self.makeClient()
            guard await Self.waitUntilReady(client: client, port: port, serveTask: serveTask) else {
                await Self.stop(serveTask, installation)
                continue
            }
            do {
                try await body(client, "http://127.0.0.1:\(port)")
                await Self.stop(serveTask, installation)
                return
            } catch {
                await Self.stop(serveTask, installation)
                throw error
            }
        }
        throw HostTestError.serverNeverBecameReady
    }

    private static func makeClient() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }

    private static func waitUntilReady(
        client: URLSession,
        port: Int,
        serveTask: Task<Void, any Error>
    ) async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        for _ in 0..<100 {
            if serveTask.isCancelled {
                return false
            }
            do {
                _ = try await client.data(from: url)
                return true
            } catch {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return false
                }
            }
        }
        return false
    }

    private static func stop(_ serveTask: Task<Void, any Error>, _ installation: HTTPServerAppInstallation) async {
        serveTask.cancel()
        installation.shutdown()
        _ = await serveTask.result
    }
}

// MARK: - Fixtures

private struct HostFixtureApp: App {
    var body: some Scene {
        HostRootPage()
        HostItemPage()
        HostSearchPage()
        HostSessionReadPage()
        HostSessionLoginPage()
        SSEEndpoint(HostTickerRoute.self, path: "/events")
    }
}

@Page("/")
private struct HostRootPage {
    func body() -> some HTML {
        main {
            h1 { "Host Root" }
        }
    }
}

@Page("/items/:id")
private struct HostItemPage {
    struct Params: Decodable, Sendable {
        let id: Int
    }

    func body() -> some HTML {
        main {
            h1 { "Item" }
        }
    }
}

@Page("/search")
private struct HostSearchPage {
    struct SearchParams: Decodable, Sendable {
        let q: String
    }

    @Query var query: SearchParams

    func body() -> some HTML {
        main {
            p { query.q }
        }
    }
}

@Page("/session")
private struct HostSessionReadPage {
    @Session var session

    func body() -> some HTML {
        main {
            p { session.isAuthenticated ? "authenticated" : "guest" }
        }
    }
}

@Page("/session/login")
private struct HostSessionLoginPage {
    @Session var session

    func body() -> some HTML {
        session.authenticate(userID: "host-user")
        return main {
            p { "logged in" }
        }
    }
}

private struct HostEchoFormAction: FormAction {
    struct Input: Decodable, Sendable {
        let message: String
    }

    init() {}

    func call(_ context: ActionContext<NoParams, Input>) async throws -> ActionResult {
        .text("message:\(context.input.message)")
    }
}

private struct HostTickerRoute: SSERoute {
    init() {}

    func events(_ context: SSEContext<NoSearchParams>) async throws -> AsyncThrowingStream<SSEEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(SSEEvent(data: "tick-1"))
            continuation.finish()
        }
    }
}
