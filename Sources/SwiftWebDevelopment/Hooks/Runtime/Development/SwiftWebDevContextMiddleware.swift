import ServiceContextModule
import SwiftWebCore

struct SwiftWebDevContextMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let context = SwiftWebDevContextCarrier.extract(from: request.headers)
        return try await ServiceContext.withValue(context) {
            try await next.respond(to: request)
        }
    }
}
