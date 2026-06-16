import Foundation
import HTTPTypes

public enum ActionResult: Sendable, Codable {
    case html(String, status: HTTPStatus = .ok)
    case text(String, status: HTTPStatus = .ok)
    case json(String, status: HTTPStatus = .ok)
    case redirect(String, status: HTTPStatus = .seeOther)
    case invalidate(InvalidationScope, status: HTTPStatus = .ok)
    case empty(status: HTTPStatus = .noContent)

    public static func html(_ content: some HTML, status: HTTPStatus = .ok) -> ActionResult {
        let artifact = content.renderArtifact(environment: .swiftWebCurrent, options: SwiftWebRenderOptions.current)
        SwiftWebDiagnostics.emit(artifact.diagnostics)
        return .html(artifact.html, status: status)
    }
}

public enum InvalidationScope: Sendable, Codable, Equatable {
    case page
    case path(String)
}

private enum ActionResultKind: String, Codable {
    case html
    case text
    case json
    case redirect
    case invalidate
    case empty
}

private struct ActionResultPayload: Codable {
    let kind: ActionResultKind
    let body: String?
    let statusCode: Int
}

extension ActionResult {
    private var payload: ActionResultPayload {
        switch self {
        case .html(let body, let status):
            ActionResultPayload(kind: .html, body: body, statusCode: status.code)
        case .text(let body, let status):
            ActionResultPayload(kind: .text, body: body, statusCode: status.code)
        case .json(let body, let status):
            ActionResultPayload(kind: .json, body: body, statusCode: status.code)
        case .redirect(let location, let status):
            ActionResultPayload(kind: .redirect, body: location, statusCode: status.code)
        case .invalidate(let scope, let status):
            ActionResultPayload(kind: .invalidate, body: scope.path, statusCode: status.code)
        case .empty(let status):
            ActionResultPayload(kind: .empty, body: nil, statusCode: status.code)
        }
    }

    public init(from decoder: Decoder) throws {
        let payload = try ActionResultPayload(from: decoder)
        let status = HTTPStatus(code: payload.statusCode)

        switch payload.kind {
        case .html:
            self = .html(payload.body ?? "", status: status)
        case .text:
            self = .text(payload.body ?? "", status: status)
        case .json:
            self = .json(payload.body ?? "", status: status)
        case .redirect:
            self = .redirect(payload.body ?? "/", status: status)
        case .invalidate:
            if let path = payload.body {
                self = .invalidate(.path(path), status: status)
            } else {
                self = .invalidate(.page, status: status)
            }
        case .empty:
            self = .empty(status: status)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try payload.encode(to: encoder)
    }
}

extension ActionResult: ResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        switch self {
        case .html(let body, let status):
            return Response(
                status: status,
                headers: [.contentType: "text/html; charset=utf-8"],
                body: .init(string: body)
            )
        case .text(let body, let status):
            return Response(
                status: status,
                headers: [.contentType: "text/plain; charset=utf-8"],
                body: .init(string: body)
            )
        case .json(let body, let status):
            return Response(
                status: status,
                headers: [.contentType: "application/json; charset=utf-8"],
                body: .init(string: body)
            )
        case .redirect(let location, let status):
            let security = request.application.securityConfiguration
            let validatedLocation = try security.redirects.validatedLocation(
                location,
                for: request,
                forwardedHeaders: security.forwardedHeaders
            )
            return Response(
                status: status,
                headers: [HTTPField.Name("Location")!: validatedLocation],
                body: .empty
            )
        case .invalidate(let scope, let status):
            if request.headers[values: HTTPField.Name("X-SwiftWeb-Action-Mode")!].contains("client") {
                let data = try JSONEncoder().encode(payload)
                return Response(
                    status: status,
                    headers: [.contentType: "application/json; charset=utf-8"],
                    body: .init(data: data)
                )
            }
            return Response(
                status: .seeOther,
                headers: [HTTPField.Name("Location")!: fallbackLocation(for: scope, request: request)],
                body: .empty
            )
        case .empty(let status):
            return Response(status: status, body: .empty)
        }
    }

    private func fallbackLocation(for scope: InvalidationScope, request: Request) -> String {
        let security = request.application.securityConfiguration
        return security.redirects.fallbackLocation(
            candidates: [
                scope.path,
                request.headers[values: HTTPField.Name("Referer")!].first,
            ],
            for: request,
            forwardedHeaders: security.forwardedHeaders
        )
    }
}

private extension InvalidationScope {
    var path: String? {
        switch self {
        case .page:
            nil
        case .path(let path):
            path
        }
    }
}
