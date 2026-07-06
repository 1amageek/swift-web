import HTTPTypes
import Logging
import SwiftWebCore
import Synchronization

/// In-memory host application for core tests. No server, no Vapor: routes are
/// collected and requests are constructed directly.
final class TestWebApplication: WebApplicationProtocol {
    let logger = Logger(label: "swiftweb.tests")
    let storage = WebApplicationStorage()
    private let webRoutes = WebRoutes()
    private let serverConfigurationBox = Mutex(WebServerConfiguration())

    init() {}

    var routes: any WebRoutesBuilder {
        webRoutes
    }

    var collectedRoutes: [WebRoute] {
        webRoutes.all
    }

    var serverConfiguration: WebServerConfiguration {
        get {
            serverConfigurationBox.withLock { $0 }
        }
        set {
            serverConfigurationBox.withLock { $0 = newValue }
        }
    }
}

enum TestRequestError: Error {
    case unsupported(String)
}

/// An in-memory session backing a test request.
final class TestSessionStore: Sendable {
    private let values = Mutex<[String: String]>([:])

    var webSession: WebSession {
        WebSession(
            identifierReader: { "test-session" },
            valuesReader: { self.values.withLock { $0 } },
            valueReader: { key in self.values.withLock { $0[key] } },
            valueWriter: { key, value in self.values.withLock { $0[key] = value } },
            destroyHandler: { self.values.withLock { $0.removeAll() } }
        )
    }
}

extension WebRequest {
    /// A test request with the same defaults `Vapor.Request(application:)` had.
    convenience init(
        application: any WebApplicationProtocol,
        method: HTTPRequest.Method = .get,
        path: String = "/",
        headers: HTTPFields = [:],
        cookies: [String: String] = [:],
        remoteAddress: String? = nil,
        securityContext: RequestSecurityContext? = nil
    ) {
        self.init(
            method: method,
            url: WebURL(string: path, path: path),
            headers: headers,
            cookies: cookies,
            query: WebQueryContainer { _ in
                throw TestRequestError.unsupported("query decoding")
            },
            content: WebContentContainer(
                decoder: { _ in
                    throw TestRequestError.unsupported("content decoding")
                },
                fieldDecoder: { _, _ in
                    throw TestRequestError.unsupported("content field decoding")
                }
            ),
            collectBody: { nil },
            session: TestSessionStore().webSession,
            hasSession: false,
            logger: Logger(label: "swiftweb.tests.request"),
            application: application,
            remoteAddress: remoteAddress,
            securityContext: securityContext
        )
    }
}
