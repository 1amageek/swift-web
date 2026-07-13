#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import Logging
import SwiftWebCore

/// Builds the host-neutral request from an `HTTPAPIs` request and its
/// collected body for the `swift-http-server` host.
enum HTTPServerWebRequestFactory {
    static func webRequest(
        request: HTTPRequest,
        bodyBytes: [UInt8]?,
        parameters: WebPathParameters,
        session: HTTPServerSessionBox,
        application: HTTPServerWebApplication,
        logger: Logger
    ) -> WebRequest {
        let rawPath = request.path ?? "/"
        let parts = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = parts.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 } ?? "/"
        let queryString = parts.count > 1 ? String(parts[1]) : nil
        let scheme = request.scheme ?? "http"
        let host = request.headerFields[HTTPField.Name("Host")!] ?? request.authority

        let cookieHeader = request.headerFields[values: .cookie].joined(separator: "; ")
        let cookies = WebHTTPCookieParser.parse(cookieHeader: cookieHeader)

        let contentType = request.headerFields[.contentType]

        return WebRequest(
            method: request.method,
            url: WebURL(
                string: rawPath,
                scheme: scheme,
                host: host,
                path: path,
                query: queryString
            ),
            headers: request.headerFields,
            cookies: cookies,
            query: WebQueryContainer { type in
                try WebURLEncodedFormDecoder().decode(type, from: queryString ?? "")
            },
            content: WebContentContainer(
                decoder: { type in
                    try Self.decodeContent(type, contentType: contentType, bodyBytes: bodyBytes)
                },
                fieldDecoder: { type, name in
                    throw Abort(
                        .unsupportedMediaType,
                        reason: "Multipart field decoding ('\(name)' as \(type)) is not supported on the swift-http-server host yet"
                    )
                }
            ),
            collectBody: { bodyBytes },
            session: session.webSession,
            hasSession: session.hasExistingSession,
            logger: logger,
            application: application,
            remoteAddress: nil,
            parameters: parameters
        )
    }

    private static func decodeContent(
        _ type: any Decodable.Type,
        contentType: String?,
        bodyBytes: [UInt8]?
    ) throws -> any Decodable {
        guard let bodyBytes, !bodyBytes.isEmpty else {
            throw Abort(.badRequest, reason: "Request body is empty")
        }
        // Trim without `CharacterSet.whitespaces`: the member is declared by
        // both Foundation and FoundationEssentials on Linux and the lookup is
        // ambiguous there.
        let mediaType = contentType?
            .split(separator: ";", maxSplits: 1)
            .first
            .map { slice in
                var trimmed = slice
                while let first = trimmed.first, first.isWhitespace {
                    trimmed = trimmed.dropFirst()
                }
                while let last = trimmed.last, last.isWhitespace {
                    trimmed = trimmed.dropLast()
                }
                return trimmed.lowercased()
            }
        switch mediaType {
        case "application/json":
            return try JSONDecoder().decode(type, from: Data(bodyBytes))
        case "application/x-www-form-urlencoded":
            return try WebURLEncodedFormDecoder().decode(
                type,
                from: String(decoding: bodyBytes, as: UTF8.self)
            )
        default:
            throw Abort(
                .unsupportedMediaType,
                reason: "Content type '\(contentType ?? "none")' is not supported on the swift-http-server host"
            )
        }
    }
}
