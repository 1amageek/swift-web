import HTTPTypes
import Logging
import SwiftWebCore
import Synchronization

/// In-memory host application for core tests. No server, no Vapor: routes are
/// collected and requests are constructed directly.
final class TestWebApplication: ApplicationProtocol {
    let logger = Logger(label: "swiftweb.tests")
    let storage = ApplicationStorage()
    private let webRoutes = Routes()
    private let serverConfigurationBox = Mutex(ServerConfiguration())

    init() {}

    var routes: any RoutesBuilder {
        webRoutes
    }

    var collectedRoutes: [Route] {
        webRoutes.all
    }

    var serverConfiguration: ServerConfiguration {
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

    var webSession: RequestSession {
        RequestSession(
            identifierReader: { "test-session" },
            valuesReader: { self.values.withLock { $0 } },
            valueReader: { key in self.values.withLock { $0[key] } },
            valueWriter: { key, value in self.values.withLock { $0[key] = value } },
            destroyHandler: { self.values.withLock { $0.removeAll() } }
        )
    }
}

extension Request {
    /// A test request with the same defaults `Vapor.Request(application:)` had.
    convenience init(
        application: any ApplicationProtocol,
        method: HTTPRequest.Method = .get,
        path: String = "/",
        headers: HTTPFields = [:],
        cookies: [String: String] = [:],
        remoteAddress: String? = nil,
        securityContext: RequestSecurityContext? = nil
    ) {
        self.init(
            method: method,
            url: {
                let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
                let query = parts.count > 1 ? String(parts[1]) : nil
                return RequestURL(string: path, path: String(parts[0]), query: query)
            }(),
            headers: headers,
            cookies: cookies,
            content: ContentContainer(
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
