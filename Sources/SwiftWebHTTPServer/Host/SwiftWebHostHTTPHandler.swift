import HTTPAPIs
import HTTPTypes
import Logging
import NIOCore
import NIOHTTPServer
import SwiftWebCore

/// Serves the app's collected routes on `NIOHTTPServer`:
/// match → session → middleware chain → handler → write (buffered or streamed).
struct SwiftWebHostHTTPHandler: HTTPServerRequestHandler {
    typealias RequestReader = HTTPRequestConcludingAsyncReader
    typealias ResponseWriter = HTTPResponseConcludingAsyncWriter

    /// Applied when a route uses `.collect(maxSize: nil)`.
    static let defaultMaxBodySize = 16 * 1024 * 1024

    let application: HTTPServerWebApplication
    let matcher: WebRouteMatcher
    let chain: WebMiddlewares
    let sessionStorage: any HTTPServerSessionStorage
    let logger: Logger

    func handle(
        request: HTTPRequest,
        requestContext: HTTPRequestContext,
        requestBodyAndTrailers: consuming sending HTTPRequestConcludingAsyncReader,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        let rawPath = request.path ?? "/"
        let pathOnly = String(rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "/")
        let match = matcher.match(method: request.method, path: pathOnly)

        let bodyLimit: Int
        switch match?.route.bodyStrategy {
        case .collect(let maxSize):
            bodyLimit = maxSize ?? Self.defaultMaxBodySize
        case .stream, nil:
            // Request-body streaming is not exposed to handlers yet; buffered
            // collection keeps `.stream` routes functional within the limit.
            bodyLimit = Self.defaultMaxBodySize
        }

        let bodyBytes: [UInt8]?
        do {
            bodyBytes = try await Self.collectRequestBody(requestBodyAndTrailers, limit: bodyLimit)
        } catch let error as BodyTooLargeError {
            _ = error
            let response = HTTPServerErrorResponder.errorResponse(
                status: .contentTooLarge,
                reason: "Request body exceeds the route's collection limit"
            )
            try await Self.send(response, responseSender: responseSender)
            return
        }

        let session = HTTPServerSessionBox(
            cookieValue: Self.sessionCookie(in: request),
            storage: sessionStorage
        )
        let webRequest = HTTPServerWebRequestFactory.webRequest(
            request: request,
            bodyBytes: bodyBytes,
            parameters: match?.parameters ?? WebPathParameters(),
            session: session,
            application: application,
            logger: logger
        )

        let terminal = HTTPServerErrorResponder(
            next: HTTPServerRouteResponder(match: match),
            logger: logger
        )
        var response: WebResponse
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
        try await Self.send(response, responseSender: responseSender)
    }

    private static func sessionCookie(in request: HTTPRequest) -> String? {
        let header = request.headerFields[values: .cookie].joined(separator: "; ")
        return WebHTTPCookieParser.parse(cookieHeader: header)[HTTPServerSessionBox.cookieName]
    }

    private static func send(
        _ response: WebResponse,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        let writer = try await responseSender.send(
            HTTPResponse(status: response.status, headerFields: response.headers)
        )
        if let produce = response.body.stream {
            try await writer.produceAndConclude { responseBodyWriter in
                var responseBodyWriter = responseBodyWriter
                // The body writer is not Sendable, so the producer yields
                // chunks through a stream and this loop performs the writes.
                let (chunks, continuation) = AsyncThrowingStream<[UInt8], any Error>.makeStream()
                async let producing: Void = {
                    do {
                        try await produce(HTTPServerWebBodyWriter(continuation: continuation))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }()
                for try await chunk in chunks {
                    try await responseBodyWriter.write(chunk.span)
                }
                await producing
                return ((), nil)
            }
        } else {
            let bytes = response.body.bytes ?? []
            try await writer.produceAndConclude { responseBodyWriter in
                var responseBodyWriter = responseBodyWriter
                if !bytes.isEmpty {
                    try await responseBodyWriter.write(bytes.span)
                }
                return ((), nil)
            }
        }
    }

    struct BodyTooLargeError: Error {}

    private static func collectRequestBody(
        _ requestBodyAndTrailers: consuming sending HTTPRequestConcludingAsyncReader,
        limit: Int
    ) async throws -> [UInt8]? {
        let collected = try await requestBodyAndTrailers.consumeAndConclude { reader in
            var reader = reader
            var body = ByteBuffer()
            while true {
                let reachedEnd = try await reader.read { buffer in
                    if buffer.isEmpty {
                        return true
                    }
                    body.writeBytes(buffer.span.bytes)
                    return false
                }
                if body.readableBytes > limit {
                    throw BodyTooLargeError()
                }
                if reachedEnd {
                    break
                }
            }
            return body
        }
        var body = collected.0
        guard body.readableBytes > 0 else {
            return nil
        }
        return body.readBytes(length: body.readableBytes)
    }
}

private struct HTTPServerWebBodyWriter: WebBodyWriter {
    let continuation: AsyncThrowingStream<[UInt8], any Error>.Continuation

    func write(_ bytes: [UInt8]) async throws {
        continuation.yield(bytes)
    }
}

/// The end of the middleware chain: run the matched route or 404.
private struct HTTPServerRouteResponder: WebResponder {
    let match: WebRouteMatch?

    func respond(to request: WebRequest) async throws -> WebResponse {
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
