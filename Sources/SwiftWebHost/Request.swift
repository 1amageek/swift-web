import HTTPTypes
#if canImport(Logging)
import Logging
#endif
import Synchronization

/// The host-neutral request the SwiftWeb core programs against, replacing `Vapor.Request`.
/// A host adapter constructs one per request from its native request and shares the same
/// instance across middleware and the route handler, so request-scoped state
/// (security context, path parameters) is visible everywhere. Core never sees a host type.
public final class Request: Sendable {
    public let method: HTTPRequest.Method
    public let url: RequestURL
    public let cookies: [String: String]
    public let content: ContentContainer
    public let session: RequestSession
    public let hasSession: Bool
    public let logger: Logger
    public let application: any ApplicationProtocol
    /// The client IP address, if the host knows it.
    public let remoteAddress: String?

    private let headersBox: Mutex<HTTPFields>
    private let securityContextBox: Mutex<RequestSecurityContext?>
    private let parametersBox: Mutex<PathParameters>
    private let bodyCollector: @Sendable () async throws -> [UInt8]?

    public init(
        method: HTTPRequest.Method,
        url: RequestURL,
        headers: HTTPFields,
        cookies: [String: String],
        content: ContentContainer,
        collectBody: @escaping @Sendable () async throws -> [UInt8]?,
        session: RequestSession,
        hasSession: Bool,
        logger: Logger,
        application: any ApplicationProtocol,
        remoteAddress: String? = nil,
        parameters: PathParameters = PathParameters(),
        securityContext: RequestSecurityContext? = nil
    ) {
        self.method = method
        self.url = url
        self.headersBox = Mutex(headers)
        self.cookies = cookies
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

    /// The parsed query string, with framework-defined semantics identical
    /// on every host (see `QueryParameters`).
    public var queryParameters: QueryParameters {
        QueryParameters(rawQuery: url.query)
    }

    /// Path parameters captured by the host router. The adapter sets them after
    /// route matching, before the handler runs.
    public var parameters: PathParameters {
        get {
            parametersBox.withLock { $0 }
        }
        set {
            parametersBox.withLock { $0 = newValue }
        }
    }

    public func redirect(to location: String, status: HTTPResponse.Status = .seeOther) -> Response {
        .redirect(to: location, status: status)
    }
}
