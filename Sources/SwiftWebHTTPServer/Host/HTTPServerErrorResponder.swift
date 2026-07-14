#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import Logging
import SwiftWebCore

/// Converts errors thrown by routed handlers into responses, mirroring
/// Vapor's `ErrorMiddleware` wire shape (`{"error":true,"reason":...}`).
/// Sits inside the SwiftWeb middleware chain so security/CORS headers still
/// decorate error responses.
final class HTTPServerErrorResponder: Responder {
    let next: any Responder
    let logger: Logger

    init(next: any Responder, logger: Logger) {
        self.next = next
        self.logger = logger
    }

    func respond(to request: Request) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let abort as Abort {
            return Self.errorResponse(status: abort.status, reason: abort.reason ?? abort.status.reasonPhrase)
        } catch let error as DecodingError {
            logger.debug("Request decoding failed: \(String(describing: error))")
            return Self.errorResponse(status: .badRequest, reason: "Request payload could not be decoded")
        } catch {
            logger.error("Unhandled route error: \(String(describing: error))")
            return Self.errorResponse(status: .internalServerError, reason: "Something went wrong")
        }
    }

    static func errorResponse(status: HTTPResponse.Status, reason: String) -> Response {
        struct ErrorBody: Encodable {
            let error: Bool
            let reason: String
        }
        var headers = HTTPFields()
        headers[.contentType] = "application/json; charset=utf-8"
        let body: Response.Body
        do {
            body = .init(data: try JSONEncoder().encode(ErrorBody(error: true, reason: reason)))
        } catch {
            body = .init(string: #"{"error":true,"reason":"Something went wrong"}"#)
        }
        return Response(status: status, headers: headers, body: body)
    }
}
