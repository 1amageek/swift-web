import HTTPTypes
import Logging
import SwiftWebBrowserRuntime
@_spi(Hosting) @testable import SwiftWebCore
import Synchronization

/// In-memory rendering and request runtime for focused core tests.
final class TestWebRuntime {
    let logger = Logger(label: "swiftweb.tests")
    let runtime: AppRuntime

    init(serverConfiguration: ServerConfiguration = ServerConfiguration()) {
        self.runtime = AppRuntime(serverConfiguration: serverConfiguration)
    }

    var routes: any RoutesBuilder {
        runtime.routes
    }

    var collectedRoutes: [Route] {
        runtime.routes.all
    }

    var requestContext: RequestRuntimeContext {
        runtime.requestContext
    }

    var pageActionContext: PageActionRegistrationContext {
        PageActionRegistrationContext(runtime: runtime, routes: runtime.routes)
    }

    var securityConfiguration: SecurityConfiguration {
        get {
            runtime.requestContext.securityConfiguration
        }
        set {
            runtime.requestContext.securityConfiguration = newValue
        }
    }

    var swiftWebClientRuntime: SwiftWebClientRuntime {
        get {
            runtime.requestContext.swiftWebClientRuntime
        }
        set {
            runtime.requestContext.swiftWebClientRuntime = newValue
        }
    }

    var swiftWebServerActions: ServerActionRegistry {
        runtime.requestContext.swiftWebServerActions
    }
}

enum TestRequestError: Error {
    case unsupported(String)
}

/// An in-memory session backing a test request.
final class TestSessionStore: Sendable {
    private let identifier: String?
    private let values = Mutex<[String: String]>([:])

    init(identifier: String? = "test-session") {
        self.identifier = identifier
    }

    var webSession: RequestSession {
        RequestSession(
            identifierReader: { self.identifier },
            valuesReader: { self.values.withLock { $0 } },
            valueReader: { key in self.values.withLock { $0[key] } },
            valueWriter: { key, value in self.values.withLock { $0[key] = value } },
            destroyHandler: { self.values.withLock { $0.removeAll() } }
        )
    }
}

extension Request {
    /// A focused request fixture backed by the same runtime context as routes.
    convenience init(
        runtime: TestWebRuntime,
        method: HTTPRequest.Method = .get,
        path: String = "/",
        headers: HTTPFields = [:],
        cookies: [String: String] = [:],
        remoteAddress: String? = nil,
        securityContext: RequestSecurityContext? = nil,
        sessionID: String? = "test-session"
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
            session: TestSessionStore(identifier: sessionID).webSession,
            hasSession: false,
            logger: Logger(label: "swiftweb.tests.request"),
            runtimeContext: runtime.requestContext,
            remoteAddress: remoteAddress,
            securityContext: securityContext
        )
    }

    /// A request fixture using the runtime context returned by app rendering.
    convenience init(
        renderedApp: RenderedApp,
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
            runtimeContext: renderedApp.requestContext,
            remoteAddress: remoteAddress,
            securityContext: securityContext
        )
    }
}
