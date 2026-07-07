import BasicContainers
import HTTPAPIs
import HTTPTypes
import Logging
import NIOCore
import NIOHTTPServer
import SwiftWebCore

/// Serves the app's collected routes on `NIOHTTPServer`:
/// match → session → middleware chain → handler → write (buffered or streamed).
struct SwiftWebHostHTTPHandler: HTTPServerRequestHandler {
    typealias RequestContext = NIOHTTPServer.RequestContext
    typealias Reader = NIOHTTPServer.Reader
    typealias ResponseSender = NIOHTTPServer.ResponseSender

    /// Applied when a route uses `.collect(maxSize: nil)`.
    static let defaultMaxBodySize = 16 * 1024 * 1024

    let application: HTTPServerWebApplication
    let matcher: WebRouteMatcher
    let chain: WebMiddlewares
    let sessionStorage: any HTTPServerSessionStorage
    let logger: Logger

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
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
                    try await produce(HTTPServerWebBodyWriter(continuation: continuation))
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
