import Foundation
import HTTPTypes
import Logging
import NIOCore
import NIOPosix
import SwiftHTML
import TLS
import SwiftWeb
@_spi(Hosting) import SwiftWebHost
@testable import SwiftWebHTTPServerHost
import Synchronization
import Testing

@Suite
struct SwiftWebHTTPServerHostTests {
    @Test
    func nioWebSocketStorageReusesItsNativeOwner() throws {
        var source = ByteBufferAllocator().buffer(capacity: 5)
        source.writeBytes([0x00, 0x01, 0x02, 0x03, 0x04])
        let storage = NIOWebSocketBinaryStorage(source)
        let message = WebSocketBinaryBuffer(storage: storage)[1..<4]

        let outbound = NIOWebSocketBinaryStorage.byteBuffer(for: message)
        let sourceAddress = source.withUnsafeReadableBytes { bytes in
            UInt(bitPattern: bytes.baseAddress!.advanced(by: 1))
        }
        let outboundAddress = outbound.withUnsafeReadableBytes { bytes in
            UInt(bitPattern: bytes.baseAddress!)
        }

        #expect(outboundAddress == sourceAddress)
        #expect(outbound.readableBytesView.elementsEqual([0x01, 0x02, 0x03]))
    }

    @Test
    func endpointStringFormDeclaresCachePolicy() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/cached.txt")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")
            #expect(http.value(forHTTPHeaderField: "Cache-Control") == "public, max-age=600, s-maxage=3600")
            #expect(String(decoding: data, as: UTF8.self) == "cached fixture")
        }
    }

    @Test
    func endpointStringFormOmitsCacheControlByDefault() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/plain.txt")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Cache-Control") == nil)
            #expect(String(decoding: data, as: UTF8.self) == "plain fixture")
        }
    }

    @Test
    func endpointResponseFormServesBinaryWithCustomHeaders() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/binary")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
            #expect(http.value(forHTTPHeaderField: "ETag") == "\"fixture-v1\"")
            #expect(data == Data([0x01, 0x02, 0xFF]))
        }
    }

    @Test
    func endpointResponseFormServesNonOKStatus() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (data, response) = try await client.data(from: URL(string: "\(base)/missing-resource")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 404)
            #expect(String(decoding: data, as: UTF8.self) == "missing")
        }
    }

    @Test
    func pageInheritsGroupCachePolicy() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (_, response) = try await client.data(from: URL(string: "\(base)/cached-group/inherit")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Cache-Control") == "public, max-age=120")
        }
    }

    @Test
    func pageOverridesGroupCachePolicy() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (_, response) = try await client.data(from: URL(string: "\(base)/cached-group/override")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        }
    }

    @Test
    func pageOutsideCachedGroupOmitsCacheControl() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (_, response) = try await client.data(from: URL(string: "\(base)/")!)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(http.value(forHTTPHeaderField: "Cache-Control") == nil)
        }
    }

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
        try await withHost(HostFixtureApp()) { client, base in
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
    func postEndpointExternalReceivesRawBodyWithoutCSRF() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            var request = URLRequest(url: URL(string: "\(base)/hooks/echo")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"event":"payment.succeeded"}"#.utf8)
            let (data, response) = try await client.data(for: request)
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self) == #"{"event":"payment.succeeded"}"#)
        }
    }

    @Test
    func postEndpointExternalPropagatesThrownAbort() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            var request = URLRequest(url: URL(string: "\(base)/hooks/rejecting")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"event":"tampered"}"#.utf8)
            let (_, response) = try await client.data(for: request)
            #expect((response as? HTTPURLResponse)?.statusCode == 400)
        }
    }

    @Test
    func postEndpointSessionModeEnforcesCSRF() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let (_, pageResponse) = try await client.data(from: URL(string: "\(base)/")!)
            let pageHTTP = try #require(pageResponse as? HTTPURLResponse)
            let setCookie = try #require(pageHTTP.value(forHTTPHeaderField: "Set-Cookie"))
            let csrfCookie = try #require(setCookie.split(separator: ";").first.map(String.init))
            let token = try #require(csrfCookie.split(separator: "=", maxSplits: 1).last.map(String.init))

            var missingToken = URLRequest(url: URL(string: "\(base)/api/echo")!)
            missingToken.httpMethod = "POST"
            missingToken.setValue("application/json", forHTTPHeaderField: "Content-Type")
            missingToken.setValue(csrfCookie, forHTTPHeaderField: "Cookie")
            missingToken.httpBody = Data(#"{"note":"hi"}"#.utf8)
            let (_, forbidden) = try await client.data(for: missingToken)
            #expect((forbidden as? HTTPURLResponse)?.statusCode == 403)

            var valid = URLRequest(url: URL(string: "\(base)/api/echo")!)
            valid.httpMethod = "POST"
            valid.setValue("application/json", forHTTPHeaderField: "Content-Type")
            valid.setValue(csrfCookie, forHTTPHeaderField: "Cookie")
            valid.setValue(token, forHTTPHeaderField: "X-CSRF-Token")
            valid.httpBody = Data(#"{"note":"hi"}"#.utf8)
            let (data, ok) = try await client.data(for: valid)
            #expect((ok as? HTTPURLResponse)?.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self) == #"{"note":"hi"}"#)
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

    @Test(.timeLimit(.minutes(1)))
    func upgradesAndEchoesBinaryWebSocketMessages() async throws {
        try await withHost(HostFixtureApp()) { client, base in
            let webSocketURL = try #require(
                Self.webSocketURL(base: base, path: "/binary-socket")
            )
            let socket = client.webSocketTask(with: webSocketURL)
            socket.resume()
            defer {
                socket.cancel(with: .normalClosure, reason: nil)
            }

            let expected = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
            try await socket.send(.data(expected))
            let message = try await socket.receive()
            guard case .data(let received) = message else {
                Issue.record("Expected a binary WebSocket response")
                return
            }
            #expect(received == expected)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func servesHTTPSAndSecureWebSocketMessages() async throws {
        try await withTLSHost(HostFixtureApp()) { client, base in
            let (schemeData, schemeResponse) = try await client.data(
                from: URL(string: "\(base)/request-scheme")!
            )
            #expect((schemeResponse as? HTTPURLResponse)?.statusCode == 200)
            #expect(String(decoding: schemeData, as: UTF8.self) == "https")

            let webSocketURL = try #require(
                Self.webSocketURL(base: base, path: "/scheme-binary-socket")
            )
            #expect(webSocketURL.scheme == "wss")
            let socket = client.webSocketTask(with: webSocketURL)
            socket.resume()
            defer {
                socket.cancel(with: .normalClosure, reason: nil)
            }

            let schemeMessage = try await socket.receive()
            guard case .string(let scheme) = schemeMessage else {
                Issue.record("Expected the secure request scheme")
                return
            }
            #expect(scheme == "https")

            let expected = Data(repeating: 0xA5, count: 1_048_576)
            try await socket.send(.data(expected))
            let echoMessage = try await socket.receive()
            guard case .data(let received) = echoMessage else {
                Issue.record("Expected a binary secure WebSocket response")
                return
            }
            #expect(received == expected)
        }
    }

    @Test
    func rejectsTLSWithoutAServerIdentity() {
        #expect(throws: HTTPServerTransportConfigurationError.missingServerIdentity) {
            _ = try HTTPServerTransportConfiguration.tls(
                TLSConfiguration(alpnProtocols: ["http/1.1"])
            )
        }
    }

    @Test
    func rejectsUnsupportedTLSApplicationProtocols() {
        var configuration = HostTLSTestIdentity.serverConfiguration()
        configuration.alpnProtocols = ["h2", "http/1.1"]

        #expect(
            throws: HTTPServerTransportConfigurationError.unsupportedApplicationProtocol("h2")
        ) {
            _ = try HTTPServerTransportConfiguration.tls(configuration)
        }
    }

    @Test
    func peerDisconnectAndShutdownAreNotLoggedAsConnectionFailures() async throws {
        let logStore = HostLogStore()
        let logger = Logger(label: "swiftweb.tests.host", factory: { _ in
            HostRecordingLogHandler(store: logStore)
        })

        for _ in 0..<5 {
            let port = Int.random(in: 20_000..<60_000)
            let host = HTTPServerHost(hostname: "127.0.0.1", port: port)
            let installation = try await host.render(HostFixtureApp(), logger: logger)
            let serveTask = Task {
                try await installation.serve()
            }
            let client = Self.makeClient()
            guard await Self.waitUntilReady(client: client, port: port, serveTask: serveTask) else {
                try await Self.stop(serveTask, installation)
                continue
            }

            try await Self.connectAndDisconnect(port: port)
            try await Task.sleep(for: .milliseconds(100))

            let (_, response) = try await client.data(
                from: URL(string: "http://127.0.0.1:\(port)/")!
            )
            #expect((response as? HTTPURLResponse)?.statusCode == 200)

            try await Self.stop(serveTask, installation)
            #expect(!logStore.contains("SwiftWeb connection failed"))
            return
        }

        throw HostTestError.serverNeverBecameReady
    }

    // MARK: - Harness

    private enum HostTestError: Error {
        case serverNeverBecameReady
    }

    private func withHost<Definition: App>(
        _ app: Definition,
        _ body: (URLSession, String) async throws -> Void
    ) async throws {
        for _ in 0..<5 {
            let port = Int.random(in: 20_000..<60_000)
            let host = HTTPServerHost(hostname: "127.0.0.1", port: port)
            let installation = try await host.render(
                app,
                logger: Logger(label: "swiftweb.tests.host")
            )
            let serveTask = Task {
                try await installation.serve()
            }
            let client = Self.makeClient()
            guard await Self.waitUntilReady(client: client, port: port, serveTask: serveTask) else {
                try await Self.stop(serveTask, installation)
                continue
            }
            do {
                try await body(client, "http://127.0.0.1:\(port)")
                try await Self.stop(serveTask, installation)
                return
            } catch {
                try await Self.stop(serveTask, installation)
                throw error
            }
        }
        throw HostTestError.serverNeverBecameReady
    }

    private func withTLSHost<Definition: App>(
        _ app: Definition,
        _ body: (URLSession, String) async throws -> Void
    ) async throws {
        var serverConfiguration = HostTLSTestIdentity.serverConfiguration()
        serverConfiguration.alpnProtocols = []
        let transport = try HTTPServerTransportConfiguration.tls(
            serverConfiguration
        )
        for _ in 0..<5 {
            let port = Int.random(in: 20_000..<60_000)
            let host = HTTPServerHost(
                hostname: "127.0.0.1",
                port: port,
                transport: transport
            )
            var logger = Logger(label: "swiftweb.tests.host.tls")
            logger.logLevel = .trace
            let installation = try await host.render(app, logger: logger)
            let serveTask = Task {
                try await installation.serve()
            }
            let client = Self.makeTLSClient()
            let base = "https://127.0.0.1:\(port)"
            guard await Self.waitUntilReady(
                client: client,
                url: URL(string: "\(base)/")!,
                serveTask: serveTask
            ) else {
                client.invalidateAndCancel()
                try await Self.stop(serveTask, installation)
                continue
            }
            do {
                try await body(client, base)
                client.invalidateAndCancel()
                try await Self.stop(serveTask, installation)
                return
            } catch {
                client.invalidateAndCancel()
                try await Self.stop(serveTask, installation)
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

    private static func makeTLSClient() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 15
        return URLSession(
            configuration: configuration,
            delegate: HostTLSTestTrustDelegate(),
            delegateQueue: nil
        )
    }

    private static func waitUntilReady(
        client: URLSession,
        port: Int,
        serveTask: Task<Void, any Error>
    ) async -> Bool {
        await waitUntilReady(
            client: client,
            url: URL(string: "http://127.0.0.1:\(port)/")!,
            serveTask: serveTask
        )
    }

    private static func waitUntilReady(
        client: URLSession,
        url: URL,
        serveTask: Task<Void, any Error>
    ) async -> Bool {
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

    private static func webSocketURL(base: String, path: String) -> URL? {
        guard var components = URLComponents(string: base) else {
            return nil
        }
        switch components.scheme {
        case "http":
            components.scheme = "ws"
        case "https":
            components.scheme = "wss"
        default:
            return nil
        }
        components.path = path
        return components.url
    }

    private static func stop(
        _ serveTask: Task<Void, any Error>,
        _ installation: HTTPServerAppInstallation
    ) async throws {
        try await installation.shutdown()
        _ = await serveTask.result
    }

    private static func connectAndDisconnect(port: Int) async throws {
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .connect(host: "127.0.0.1", port: port)
            .get()
        try await channel.close().get()
    }
}

private final class HostLogStore: Sendable {
    private let messages = Mutex<[String]>([])

    func append(_ message: String) {
        messages.withLock { messages in
            messages.append(message)
        }
    }

    func contains(_ text: String) -> Bool {
        messages.withLock { messages in
            messages.contains { $0.contains(text) }
        }
    }
}

private struct HostRecordingLogHandler: LogHandler {
    var metadataProvider: Logger.MetadataProvider?
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace
    let store: HostLogStore

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        store.append(event.message.description)
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
        FormActionEndpoint(HostEchoFormAction.self, path: "/submit")
        SSEEndpoint(HostTickerRoute.self, path: "/events")
        WebSocketEndpoint(HostBinaryEchoRoute.self, path: "/binary-socket")
        WebSocketEndpoint(HostSchemeBinaryEchoRoute.self, path: "/scheme-binary-socket")
        Endpoint("/request-scheme", contentType: "text/plain; charset=utf-8") { request in
            request.url.scheme ?? "none"
        }
        Endpoint("/plain.txt", contentType: "text/plain; charset=utf-8") { _ in
            "plain fixture"
        }
        Endpoint(
            "/cached.txt",
            contentType: "text/plain; charset=utf-8",
            cache: .publicCache(browserSeconds: 600, sharedSeconds: 3600)
        ) { _ in
            "cached fixture"
        }
        Endpoint("/binary") { _ in
            var headers = HTTPFields()
            headers[.contentType] = "application/octet-stream"
            headers[.eTag] = "\"fixture-v1\""
            return Response(status: .ok, headers: headers, body: .init(bytes: [0x01, 0x02, 0xFF]))
        }
        Endpoint("/missing-resource") { _ in
            Response(status: .notFound, headers: HTTPFields(), body: .init(string: "missing"))
        }
        Endpoint("/hooks/echo", method: .post, security: .external) { request in
            guard let body = try await request.collectedBody() else {
                throw Abort(.badRequest, reason: "Webhook body is missing")
            }
            var headers = HTTPFields()
            headers[.contentType] = "application/octet-stream"
            return Response(status: .ok, headers: headers, body: .init(bytes: body))
        }
        Endpoint("/hooks/rejecting", method: .post, security: .external) { _ in
            throw Abort(.badRequest, reason: "signature verification failed")
        }
        Endpoint("/api/echo", method: .post) { request in
            guard let body = try await request.collectedBody() else {
                throw Abort(.badRequest, reason: "API body is missing")
            }
            var headers = HTTPFields()
            headers[.contentType] = "application/octet-stream"
            return Response(status: .ok, headers: headers, body: .init(bytes: body))
        }
        PageGroup("/cached-group") {
            HostGroupInheritCachePage()
            HostGroupOverrideCachePage()
        }
        .cache(.publicCache(seconds: 120))
    }
}

@Page("/inherit")
private struct HostGroupInheritCachePage {
    var document: some HTMLDocument {
        PageDocument(title: "Inherit") {
            main {
                p { "inherit" }
            }
        }
    }
}

@Page("/override")
private struct HostGroupOverrideCachePage {
    var cache: CachePolicy {
        get async throws {
            .noStore
        }
    }

    var document: some HTMLDocument {
        PageDocument(title: "Override") {
            main {
                p { "override" }
            }
        }
    }
}

@Page("/")
private struct HostRootPage {
    var document: some HTMLDocument {
        PageDocument(title: "Host Root") {
            main {
                h1 { "Host Root" }
            }
        }
    }
}

@Page("/items/:id")
private struct HostItemPage {
    struct Params: Decodable, Sendable {
        let id: Int
    }

    var document: some HTMLDocument {
        PageDocument(title: "Item") {
            main {
                h1 { "Item" }
            }
        }
    }
}

@Page("/search")
private struct HostSearchPage {
    struct SearchParams: Decodable, Sendable {
        let q: String
    }

    @Query var query: SearchParams

    var document: some HTMLDocument {
        PageDocument(title: "Search") {
            main {
                p { query.q }
            }
        }
    }
}

@Page("/session")
private struct HostSessionReadPage {
    @Session var session

    var document: some HTMLDocument {
        PageDocument(title: "Session") {
            main {
                p { session.isAuthenticated ? "authenticated" : "guest" }
            }
        }
    }
}

@Page("/session/login")
private struct HostSessionLoginPage {
    @Session var session

    var document: some HTMLDocument {
        session.authenticate(userID: "host-user")
        return PageDocument(title: "Login") {
            main {
                p { "logged in" }
            }
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

private struct HostBinaryEchoRoute: WebSocketRoute {
    init() {}

    func connect(_ context: WebSocketContext) async throws {
        context.onBinary { bytes in
            try await context.send(bytes)
        }
    }
}

private struct HostSchemeBinaryEchoRoute: WebSocketRoute {
    init() {}

    func connect(_ context: WebSocketContext) async throws {
        try await context.send(context.request.url.scheme ?? "none")
        context.onBinary { bytes in
            try await context.send(bytes)
        }
    }
}
