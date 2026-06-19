import AsyncHTTPClient
import Foundation
import HTTPAPIs
import HTTPTypes
import Logging
import NIOCore
import NIOHTTP1
import NIOHTTPServer
import SwiftWebDevelopmentHooks

struct SwiftWebDevHostHTTPHandler: HTTPServerRequestHandler {
    typealias RequestReader = HTTPRequestConcludingAsyncReader
    typealias ResponseWriter = HTTPResponseConcludingAsyncWriter

    private let devToken: String
    private let eventLog: SwiftWebDevEventLog
    private let workerRegistry: SwiftWebDevWorkerRegistry
    private let logger: Logger

    init(
        devToken: String,
        eventLog: SwiftWebDevEventLog,
        workerRegistry: SwiftWebDevWorkerRegistry,
        logger: Logger
    ) {
        self.devToken = devToken
        self.eventLog = eventLog
        self.workerRegistry = workerRegistry
        self.logger = logger
    }

    func handle(
        request: HTTPRequest,
        requestContext: HTTPRequestContext,
        requestBodyAndTrailers: consuming sending HTTPRequestConcludingAsyncReader,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        let body: ByteBuffer?
        do {
            body = try await Self.collectRequestBody(requestBodyAndTrailers)
        } catch {
            if SwiftWebDevExpectedTermination.isExpected(error) {
                logger.debug(
                    "SwiftWeb dev host request ended during body collection",
                    metadata: ["error": .string(String(describing: error))]
                )
                return
            }
            throw error
        }
        let target = Self.requestTarget(from: request.path ?? "/")

        switch target.path {
        case "/__dev/status":
            return try await sendStatus(responseSender: responseSender)
        case "/__swiftweb/dev/events", "/__dev/events":
            return try await sendDevEvents(target: target, responseSender: responseSender)
        case "/__swiftweb/dev/reload":
            return try await sendReload(target: target, responseSender: responseSender)
        default:
            return try await proxy(
                request: request,
                target: target,
                body: body,
                responseSender: responseSender
            )
        }
    }

    private func sendStatus(
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        let data = try JSONEncoder.swiftWebDevEvent.encode(workerRegistry.status())
        try await Self.sendBytes(
            status: .ok,
            headers: [
                .contentType: "application/json; charset=utf-8",
                .cacheControl: "no-cache, no-transform",
            ],
            bytes: Array(data),
            responseSender: responseSender
        )
    }

    private func sendDevEvents(
        target: SwiftWebDevHostRequestTarget,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        guard target.query["token"] == devToken else {
            try await Self.sendBytes(
                status: .unauthorized,
                headers: [
                    .contentType: "text/plain; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ],
                bytes: Array("invalid SwiftWeb dev event token".utf8),
                responseSender: responseSender
            )
            return
        }

        let writer = try await responseSender.send(
            HTTPResponse(
                status: .ok,
                headerFields: [
                    .contentType: "text/event-stream; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ]
            )
        )
        do {
            try await writer.produceAndConclude { responseBodyWriter in
                var responseBodyWriter = responseBodyWriter
                var lastEventID = target.query["lastEventID"]
                if lastEventID == nil {
                    let connected = SwiftWebDevEvent(kind: .connected)
                    try await responseBodyWriter.write(Array(SwiftWebDevHotReload.sseData(for: connected).utf8).span)
                    lastEventID = connected.id
                }

                var nextHeartbeat = Date().addingTimeInterval(30)
                while !Task.isCancelled {
                    let events = try eventLog.events(after: lastEventID)
                    if events.isEmpty {
                        if Date() >= nextHeartbeat {
                            try await responseBodyWriter.write(Array(": swift-web-dev heartbeat\n\n".utf8).span)
                            nextHeartbeat = Date().addingTimeInterval(30)
                        }
                        try await Task.sleep(nanoseconds: 300_000_000)
                        continue
                    }

                    for event in events {
                        try await responseBodyWriter.write(Array(SwiftWebDevHotReload.sseData(for: event).utf8).span)
                        lastEventID = event.id
                    }
                }
                return ((), nil)
            }
        } catch {
            if SwiftWebDevExpectedTermination.isExpected(error) {
                logger.debug(
                    "SwiftWeb dev event stream ended",
                    metadata: ["error": .string(String(describing: error))]
                )
                return
            }
            throw error
        }
    }

    private func sendReload(
        target: SwiftWebDevHostRequestTarget,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        if target.query["token"] == devToken {
            do {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                if error is CancellationError {
                    try await Self.sendBytes(
                        status: .noContent,
                        headers: [.cacheControl: "no-cache, no-transform"],
                        bytes: [],
                        responseSender: responseSender
                    )
                    return
                }
                throw error
            }
        }

        try await Self.sendBytes(
            status: .ok,
            headers: [
                .contentType: "text/plain; charset=utf-8",
                .cacheControl: "no-cache, no-transform",
                SwiftWebDevHotReload.reloadTokenHeaderName: devToken,
            ],
            bytes: Array(devToken.utf8),
            responseSender: responseSender
        )
    }

    private func proxy(
        request: HTTPRequest,
        target requestTarget: SwiftWebDevHostRequestTarget,
        body: ByteBuffer?,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        guard let workerTarget = workerRegistry.activeTarget() else {
            try await Self.sendBytes(
                status: .serviceUnavailable,
                headers: [
                    .contentType: "text/plain; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ],
                bytes: Array("SwiftWeb dev worker is starting".utf8),
                responseSender: responseSender
            )
            return
        }

        var context = SwiftWebDevContextCarrier.extract(from: request.headerFields)
        SwiftWebDevContextCarrier.enrich(
            &context,
            requestID: UUID().uuidString,
            workerURL: workerTarget.url,
            phase: workerRegistry.status().phase
        )

        var headers = Self.forwardHeaders(from: request.headerFields)
        Self.addForwardedHeaders(to: &headers, request: request)
        SwiftWebDevContextCarrier.inject(context, into: &headers)

        var workerRequest = try Self.httpClientRequest(
            method: request.method,
            target: workerTarget,
            requestTarget: requestTarget,
            headers: headers
        )
        if let body, body.readableBytes > 0 {
            workerRequest.body = .bytes(body)
        }

        do {
            let workerResponse = try await HTTPClient.shared.execute(
                workerRequest,
                timeout: .seconds(30),
                logger: logger
            )
            let writer = try await responseSender.send(
                HTTPResponse(
                    status: .init(code: Int(workerResponse.status.code)),
                    headerFields: Self.forwardHeaders(from: workerResponse.headers)
                )
            )
            try await writer.produceAndConclude { responseBodyWriter in
                var responseBodyWriter = responseBodyWriter
                for try await buffer in workerResponse.body {
                    try await responseBodyWriter.write(Array(buffer.readableBytesView).span)
                }
                return ((), nil)
            }
        } catch {
            if SwiftWebDevExpectedTermination.isExpected(error) {
                logger.debug(
                    "SwiftWeb dev proxied stream ended",
                    metadata: ["error": .string(String(describing: error))]
                )
                return
            }
            throw error
        }
    }

    private static func sendBytes(
        status: HTTPResponse.Status,
        headers: HTTPFields,
        bytes: [UInt8],
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        let writer = try await responseSender.send(
            HTTPResponse(status: status, headerFields: headers)
        )
        try await writer.produceAndConclude { responseBodyWriter in
            var responseBodyWriter = responseBodyWriter
            if !bytes.isEmpty {
                try await responseBodyWriter.write(bytes.span)
            }
            return ((), nil)
        }
    }

    private static func collectRequestBody(
        _ requestBodyAndTrailers: consuming sending HTTPRequestConcludingAsyncReader
    ) async throws -> ByteBuffer? {
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
                if reachedEnd {
                    break
                }
            }
            return body
        }
        return collected.0.readableBytes > 0 ? collected.0 : nil
    }

    private static func httpClientRequest(
        method: HTTPRequest.Method,
        target: SwiftWebDevWorkerTarget,
        requestTarget: SwiftWebDevHostRequestTarget,
        headers: HTTPFields
    ) throws -> HTTPClientRequest {
        let url = "http://\(target.host):\(target.port)\(requestTarget.rawValue)"
        guard URL(string: url) != nil else {
            throw SwiftWebDevRuntimeError.processFailed(command: "invalid proxy URL \(url)", status: 1)
        }

        var request = HTTPClientRequest(url: url)
        request.method = NIOHTTP1.HTTPMethod(rawValue: method.rawValue)
        for field in headers {
            request.headers.add(name: field.name.rawName, value: field.value)
        }
        if let host = headers[HTTPField.Name("Host")!] {
            request.headers.replaceOrAdd(name: "Host", value: host)
        }
        return request
    }

    private static func addForwardedHeaders(to headers: inout HTTPFields, request: HTTPRequest) {
        if let publicHost = headers[HTTPField.Name("Host")!] ?? request.authority {
            headers[HTTPField.Name("X-Forwarded-Host")!] = publicHost
        }
        headers[HTTPField.Name("X-Forwarded-Proto")!] = request.scheme ?? "http"
    }

    private static func requestTarget(from rawValue: String) -> SwiftWebDevHostRequestTarget {
        let parts = rawValue.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = parts.first.map(String.init) ?? "/"
        let queryString = parts.count > 1 ? String(parts[1]) : nil
        return SwiftWebDevHostRequestTarget(
            rawValue: rawValue,
            path: path.isEmpty ? "/" : path,
            query: queryItems(from: queryString)
        )
    }

    private static func queryItems(from queryString: String?) -> [String: String] {
        guard let queryString else {
            return [:]
        }
        var components = URLComponents()
        components.percentEncodedQuery = queryString
        var output: [String: String] = [:]
        for item in components.queryItems ?? [] {
            output[item.name] = item.value ?? ""
        }
        return output
    }

    private static func forwardHeaders(from headers: HTTPFields) -> HTTPFields {
        HTTPFields(headers.lazy.filter { field in
            !isHopByHopHeader(field.name)
        })
    }

    private static func forwardHeaders(from headers: NIOHTTP1.HTTPHeaders) -> HTTPFields {
        var fields = HTTPFields()
        for header in headers {
            guard
                let name = HTTPField.Name(header.name),
                !isHopByHopHeader(name)
            else {
                continue
            }
            fields.append(HTTPField(name: name, value: header.value))
        }
        return fields
    }

    private static func isHopByHopHeader(_ name: HTTPField.Name) -> Bool {
        switch name.canonicalName {
        case "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
             "te", "trailer", "transfer-encoding", "upgrade", "content-length":
            return true
        default:
            return false
        }
    }
}

private struct SwiftWebDevHostRequestTarget: Sendable {
    let rawValue: String
    let path: String
    let query: [String: String]
}
