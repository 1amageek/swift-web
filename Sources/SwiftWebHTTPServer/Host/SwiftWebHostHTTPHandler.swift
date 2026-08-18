import BasicContainers
import HTTPAPIs
import HTTPTypes
import Logging
import NIOCore
import NIOHTTPServer
@_spi(Hosting) import SwiftWebCore

/// Serves the app's collected routes on `NIOHTTPServer`:
/// match → session → middleware chain → handler → write (buffered or streamed).
struct SwiftWebHostHTTPHandler: HTTPServerRequestHandler {
    typealias RequestContext = NIOHTTPServer.RequestContext
    typealias Reader = NIOHTTPServer.Reader
    typealias ResponseSender = NIOHTTPServer.ResponseSender

    /// Applied when a route uses `.collect(maxSize: nil)`.
    static let defaultMaxBodySize = 16 * 1024 * 1024

    let runtimeContext: RequestRuntimeContext
    let matcher: RouteMatcher
    let chain: Middlewares
    let sessionStorage: any HTTPServerSessionStorage
    let logger: Logger

    init(
        renderedApp: RenderedApp,
        sessionStorage: any HTTPServerSessionStorage,
        logger: Logger
    ) {
        self.runtimeContext = renderedApp.requestContext
        self.matcher = RouteMatcher(routes: renderedApp.routes)
        self.chain = renderedApp.middlewares
        self.sessionStorage = sessionStorage
        self.logger = logger
    }

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        let match = httpMatch(for: request)
        let bodyLimit = bodyLimit(for: match)

        let bodyBytes: [UInt8]?
        do {
            bodyBytes = try await Self.collectRequestBody(reader, limit: bodyLimit)
        } catch let error as BodyTooLargeError {
            _ = error
            let response = HTTPServerErrorResponder.errorResponse(
                status: .contentTooLarge,
                reason: "Request body exceeds the route's collection limit"
            )
            try await Self.send(response, responseSender: responseSender)
            return
        }

        let response = await response(
            for: request,
            match: match,
            bodyBytes: bodyBytes,
            remoteAddress: nil
        )
        try await Self.send(response, responseSender: responseSender)
    }

    func httpMatch(for request: HTTPRequest) -> RouteMatch? {
        matcher.matchHTTP(method: request.method, path: Self.pathOnly(in: request))
    }

    func webSocketMatch(for request: HTTPRequest) -> RouteMatch? {
        matcher.matchWebSocket(path: Self.pathOnly(in: request))
    }

    func bodyLimit(for match: RouteMatch?) -> Int {
        switch match?.route.bodyStrategy {
        case .collect(let maxSize):
            max(0, maxSize ?? Self.defaultMaxBodySize)
        case .stream, nil:
            // Request-body streaming is not exposed to handlers yet; buffered
            // collection keeps `.stream` routes functional within the limit.
            Self.defaultMaxBodySize
        }
    }

    func response(
        for request: HTTPRequest,
        match: RouteMatch?,
        bodyBytes: [UInt8]?,
        remoteAddress: String?
    ) async -> Response {
        let (webRequest, session) = makeRequest(
            from: request,
            match: match,
            bodyBytes: bodyBytes,
            remoteAddress: remoteAddress
        )
        let terminal = HTTPServerErrorResponder(
            next: HTTPServerRouteResponder(match: match),
            logger: logger
        )
        var response: Response
        do {
            response = try await chain.makeResponder(chainingTo: terminal).respond(to: webRequest)
        } catch let abort as Abort {
            response = HTTPServerErrorResponder.errorResponse(
                status: abort.status,
                reason: abort.reason ?? abort.status.reasonPhrase
            )
        } catch {
            logger.error("Middleware chain failed: \(String(describing: error))")
            response = HTTPServerErrorResponder.errorResponse(
                status: .internalServerError,
                reason: "Something went wrong"
            )
        }
        session.finalize(response: &response)
        return response
    }

    func webSocketUpgradeHeaders(
        for request: HTTPRequest,
        remoteAddress: String?
    ) async throws -> HTTPFields? {
        guard let match = webSocketMatch(for: request),
              case .webSocket(let shouldUpgrade, _) = match.route.handler
        else {
            return nil
        }
        let (webRequest, _) = makeRequest(
            from: request,
            match: match,
            bodyBytes: nil,
            remoteAddress: remoteAddress
        )
        return try await shouldUpgrade(webRequest)
    }

    func connectWebSocket(
        for request: HTTPRequest,
        remoteAddress: String?,
        channel: any WebSocketChannel
    ) async {
        guard let match = webSocketMatch(for: request),
              case .webSocket(_, let onUpgrade) = match.route.handler
        else {
            do {
                try await channel.close()
            } catch {
                logger.error("Unmatched WebSocket close failed: \(String(describing: error))")
            }
            return
        }
        let (webRequest, _) = makeRequest(
            from: request,
            match: match,
            bodyBytes: nil,
            remoteAddress: remoteAddress
        )
        await onUpgrade(webRequest, channel)
    }

    private func makeRequest(
        from request: HTTPRequest,
        match: RouteMatch?,
        bodyBytes: [UInt8]?,
        remoteAddress: String?
    ) -> (Request, HTTPServerSessionBox) {
        let session = HTTPServerSessionBox(
            cookieValue: Self.sessionCookie(in: request),
            storage: sessionStorage
        )
        return (
            HTTPServerRequestFactory.webRequest(
                request: request,
                bodyBytes: bodyBytes,
                parameters: match?.parameters ?? PathParameters(),
                session: session,
                runtimeContext: runtimeContext,
                logger: logger,
                remoteAddress: remoteAddress
            ),
            session
        )
    }

    private static func pathOnly(in request: HTTPRequest) -> String {
        let rawPath = request.path ?? "/"
        return String(
            rawPath.split(
                separator: "?",
                maxSplits: 1,
                omittingEmptySubsequences: false
            ).first ?? "/"
        )
    }

    private static func sessionCookie(in request: HTTPRequest) -> String? {
        let header = request.headerFields[values: .cookie].joined(separator: "; ")
        return CookieParser.parse(cookieHeader: header)[HTTPServerSessionBox.cookieName]
    }

    private static func send(
        _ response: Response,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        let head = HTTPResponse(status: response.status, headerFields: response.headers)
        if let produce = response.body.stream {
            var writer = try await responseSender.send(head)
            // The body writer is not Sendable, so the producer yields chunks
            // through a stream and this loop performs the writes.
            let (chunks, continuation) = AsyncThrowingStream<[UInt8], any Error>.makeStream()
            async let producing: Void = {
                do {
                    try await produce(HTTPServerBodyWriter(continuation: continuation))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }()
            for try await chunk in chunks {
                var buffer = UniqueArray<UInt8>(copying: chunk.span)
                try await writer.write(buffer: &buffer)
            }
            await producing
            var trailing = UniqueArray<UInt8>()
            try await writer.finish(buffer: &trailing, finalElement: nil)
        } else {
            let bytes = response.body.bytes ?? []
            var buffer = UniqueArray<UInt8>(copying: bytes.span)
            try await responseSender.sendAndFinish(head, buffer: &buffer, trailer: nil)
        }
    }

    struct BodyTooLargeError: Error {}

    private static func collectRequestBody(
        _ reader: consuming sending NIOHTTPServer.Reader,
        limit: Int
    ) async throws -> [UInt8]? {
        var reader = reader
        var collected = UniqueArray<UInt8>()
        var finalElement: HTTPFields?? = nil
        while finalElement == nil {
            try await reader.read { buffer, final in
                collected.append(moving: buffer.startIndex..<buffer.endIndex, from: &buffer)
                if let final {
                    finalElement = final
                }
            }
            if collected.count > limit {
                throw BodyTooLargeError()
            }
        }
        guard !collected.isEmpty else {
            return nil
        }
        var bytes = ByteBuffer()
        bytes.writeBytes(collected.span.bytes)
        return bytes.readBytes(length: bytes.readableBytes)
    }
}

private struct HTTPServerBodyWriter: BodyWriter {
    let continuation: AsyncThrowingStream<[UInt8], any Error>.Continuation

    func write(_ bytes: [UInt8]) async throws {
        continuation.yield(bytes)
    }
}

/// The end of the middleware chain: run the matched route or 404.
private final class HTTPServerRouteResponder: Responder {
    let match: RouteMatch?

    init(match: RouteMatch?) {
        self.match = match
    }

    func respond(to request: Request) async throws -> Response {
        guard let match else {
            throw Abort(.notFound, reason: "Not Found")
        }
        switch match.route.handler {
        case .http(let handler):
            return try await handler(request)
        case .webSocket:
            throw Abort(
                .notImplemented,
                reason: "WebSocket upgrade is not supported on the swift-http-server host yet"
            )
        }
    }
}
