import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import AsyncHTTPClient
import BasicContainers
import Foundation
import HTTPAPIs
import HTTPTypes
import Logging
import NIOCore
import NIOHTTP1
import NIOHTTPServer
import SwiftWebDevelopmentHooks

struct SwiftWebDevHostHTTPHandler: HTTPServerRequestHandler {
    typealias RequestContext = NIOHTTPServer.RequestContext
    typealias Reader = NIOHTTPServer.Reader
    typealias ResponseSender = NIOHTTPServer.ResponseSender

    /// Bounds proxied request bodies so a large upload cannot exhaust dev-host
    /// memory. Matches the production host's default collection limit.
    static let defaultMaxBodySize = 16 * 1024 * 1024
    static let buildFingerprintHeaderName = HTTPField.Name("X-SwiftWeb-Dev-Build")!
    static let sourceFingerprintHeaderName = HTTPField.Name("X-SwiftWeb-Dev-Source")!
    static let staleHeaderName = HTTPField.Name("X-SwiftWeb-Dev-Stale")!

    struct BodyTooLargeError: Error {}

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
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        let body: ByteBuffer?
        do {
            body = try await Self.collectRequestBody(reader, limit: Self.defaultMaxBodySize)
        } catch is BodyTooLargeError {
            return try await Self.sendBytes(
                status: .contentTooLarge,
                headers: [
                    .contentType: "text/plain; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ],
                bytes: Array("Request body exceeds the dev host limit".utf8),
                responseSender: responseSender
            )
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
        case SwiftWebDevHotReload.clientScriptPath:
            return try await sendClientScript(responseSender: responseSender)
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
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        var status = workerRegistry.status()
        if let snapshot = await workerRegistry.reconcilerSnapshot() {
            status = status.enriched(with: snapshot)
        }
        let data = try JSONEncoder.swiftWebDevEvent.encode(status)
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

    private func sendClientScript(
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        try await Self.sendBytes(
            status: .ok,
            headers: SwiftWebDevHotReload.clientScriptHeaders(),
            bytes: Array(SwiftWebDevHotReload.clientScript().utf8),
            responseSender: responseSender
        )
    }

    private func sendDevEvents(
        target: SwiftWebDevHostRequestTarget,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
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

        var writer = try await responseSender.send(
            HTTPResponse(
                status: .ok,
                headerFields: [
                    .contentType: "text/event-stream; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ]
            )
        )
        do {
            var lastEventID = target.query["lastEventID"]
            if lastEventID == nil {
                let latestEventID = try eventLog.latestEventID()
                let connected: SwiftWebDevEvent
                if let latestEventID {
                    connected = SwiftWebDevEvent(id: latestEventID, kind: .connected)
                } else {
                    connected = SwiftWebDevEvent(kind: .connected)
                    try eventLog.append(connected)
                }
                var buffer = try UniqueArray<UInt8>(copying: Array(SwiftWebDevHotReload.sseData(for: connected).utf8).span)
                try await writer.write(buffer: &buffer)
                lastEventID = connected.id
            }

            // The incremental reader decodes only appended bytes per poll;
            // re-reading the whole log every 300 ms grew quadratically over a
            // dev session (docs/DevServerReconcilerDesign.md §8).
            let reader = try SwiftWebDevEventLogReader(log: eventLog, after: lastEventID)
            var nextHeartbeat = Date().addingTimeInterval(30)
            while !Task.isCancelled {
                let events = try reader.poll()
                if events.isEmpty {
                    if Date() >= nextHeartbeat {
                        var buffer = UniqueArray<UInt8>(copying: Array(": swift-web-dev heartbeat\n\n".utf8).span)
                        try await writer.write(buffer: &buffer)
                        nextHeartbeat = Date().addingTimeInterval(30)
                    }
                    try await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }

                for event in events {
                    var buffer = try UniqueArray<UInt8>(copying: Array(SwiftWebDevHotReload.sseData(for: event).utf8).span)
                    try await writer.write(buffer: &buffer)
                }
            }
            var trailing = UniqueArray<UInt8>()
            try await writer.finish(buffer: &trailing, finalElement: nil)
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
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        // The reload token gates the SSE event stream; never echo it to a
        // caller that did not already present it, or the gate is defeated.
        guard target.query["token"] == devToken else {
            try await Self.sendBytes(
                status: .unauthorized,
                headers: [
                    .contentType: "text/plain; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ],
                bytes: Array("invalid SwiftWeb dev reload token".utf8),
                responseSender: responseSender
            )
            return
        }

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
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        guard let workerTarget = workerRegistry.activeTarget() else {
            // While no worker serves, the body says why: a latched build
            // failure reads very differently from a first build in progress.
            var unavailableBody = "SwiftWeb dev worker is starting"
            if let snapshot = await workerRegistry.reconcilerSnapshot(),
               snapshot.phase == .failed,
               let summary = snapshot.lastErrorSummary {
                unavailableBody = "SwiftWeb dev build failed:\n\(summary)"
            }
            try await Self.sendBytes(
                status: .serviceUnavailable,
                headers: [
                    .contentType: "text/plain; charset=utf-8",
                    .cacheControl: "no-cache, no-transform",
                ],
                bytes: Array(unavailableBody.utf8),
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
            var responseHeaders = Self.forwardHeaders(from: workerResponse.headers)
            responseHeaders[HTTPField.Name("Connection")!] = "close"
            // Staleness is answerable per response: the worker already added
            // X-SwiftWeb-Dev-Build; the host adds what the sources say now
            // (docs/DevServerReconcilerDesign.md §6.1).
            if let snapshot = await workerRegistry.reconcilerSnapshot() {
                Self.addStalenessHeaders(to: &responseHeaders, snapshot: snapshot)
            }
            var writer = try await responseSender.send(
                HTTPResponse(
                    status: .init(code: Int(workerResponse.status.code)),
                    headerFields: responseHeaders
                )
            )
            for try await chunk in workerResponse.body {
                var buffer = UniqueArray<UInt8>(copying: Array(chunk.readableBytesView).span)
                try await writer.write(buffer: &buffer)
            }
            var trailing = UniqueArray<UInt8>()
            try await writer.finish(buffer: &trailing, finalElement: nil)
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
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        var buffer = UniqueArray<UInt8>(copying: bytes.span)
        try await responseSender.sendAndFinish(
            HTTPResponse(status: status, headerFields: headers),
            buffer: &buffer,
            trailer: nil
        )
    }

    static func addStalenessHeaders(
        to headers: inout HTTPFields,
        snapshot: SwiftWebDevReconcilerSnapshot
    ) {
        headers[sourceFingerprintHeaderName] = snapshot.desired.short
        headers[staleHeaderName] =
            headers[buildFingerprintHeaderName] == snapshot.desired.short ? "false" : "true"
    }

    private static func collectRequestBody(
        _ reader: consuming sending NIOHTTPServer.Reader,
        limit: Int
    ) async throws -> ByteBuffer? {
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
        var body = ByteBuffer()
        body.writeBytes(collected.span.bytes)
        return body
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
        request.headers.replaceOrAdd(name: "Connection", value: "close")
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
