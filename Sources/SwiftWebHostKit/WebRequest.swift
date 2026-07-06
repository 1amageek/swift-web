import HTTPTypes
import Logging
import Synchronization

/// The host-neutral request the SwiftWeb core programs against, replacing `Vapor.Request`.
/// A host adapter constructs one per request from its native request and shares the same
/// instance across middleware and the route handler, so request-scoped state
/// (security context, path parameters) is visible everywhere. Core never sees a host type.
public final class WebRequest: Sendable {
    public let method: HTTPRequest.Method
    public let url: WebURL
    public let cookies: [String: String]
    public let query: WebQueryContainer
    public let content: WebContentContainer
    public let session: WebSession
    public let hasSession: Bool
    public let logger: Logger
    public let application: any WebApplicationProtocol
    /// The client IP address, if the host knows it.
    public let remoteAddress: String?

    private let headersBox: Mutex<HTTPFields>
    private let securityContextBox: Mutex<RequestSecurityContext?>
    private let parametersBox: Mutex<WebPathParameters>
    private let bodyCollector: @Sendable () async throws -> [UInt8]?

    public init(
        method: HTTPRequest.Method,
        url: WebURL,
        headers: HTTPFields,
        cookies: [String: String],
        query: WebQueryContainer,
        content: WebContentContainer,
        collectBody: @escaping @Sendable () async throws -> [UInt8]?,
        session: WebSession,
        hasSession: Bool,
        logger: Logger,
        application: any WebApplicationProtocol,
        remoteAddress: String? = nil,
        parameters: WebPathParameters = WebPathParameters(),
        securityContext: RequestSecurityContext? = nil
    ) {
        self.method = method
        self.url = url
        self.headersBox = Mutex(headers)
        self.cookies = cookies
        self.query = query
        self.content = content
        self.session = session
        self.hasSession = hasSession
        self.logger = logger
        self.application = application
        self.remoteAddress = remoteAddress
        self.securityContextBox = Mutex(securityContext)
        self.parametersBox = Mutex(parameters)
        self.bodyCollector = collectBody
    }

    /// The raw request body, buffered. `nil` when the request has none.
    /// For endpoints that own their wire format (e.g. actor invocation
    /// envelopes) and decode it themselves instead of using `content`.
    public func collectedBody() async throws -> [UInt8]? {
        try await bodyCollector()
    }

    public var headers: HTTPFields {
        get {
            headersBox.withLock { $0 }
        }
        set {
            headersBox.withLock { $0 = newValue }
        }
    }

    /// The per-request security context (CSRF token / CSP nonce).
    /// Written by the security middleware, read by handlers and renderers.
    public var securityContext: RequestSecurityContext? {
        get {
            securityContextBox.withLock { $0 }
        }
        set {
            securityContextBox.withLock { $0 = newValue }
        }
    }

    /// Path parameters captured by the host router. The adapter sets them after
    /// route matching, before the handler runs.
    public var parameters: WebPathParameters {
        get {
            parametersBox.withLock { $0 }
        }
        set {
            parametersBox.withLock { $0 = newValue }
        }
    }

    public func redirect(to location: String, status: HTTPResponse.Status = .seeOther) -> WebResponse {
        .redirect(to: location, status: status)
    }
}
