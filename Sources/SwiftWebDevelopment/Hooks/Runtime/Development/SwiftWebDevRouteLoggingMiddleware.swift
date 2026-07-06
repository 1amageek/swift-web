import Foundation
import SwiftWebCore
import Logging

final class SwiftWebDevRouteLoggingMiddleware: Middleware {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SWIFT_WEB_DEV_ROUTE_LOG"] == "1"
    }

    private let logLevel: Logger.Level

    init(logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
    }

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if SwiftWebDevHotReload.shouldSuppressRouteLog(for: request) {
            return try await next.respond(to: request)
        }

        request.logger.log(
            level: logLevel,
            "\(request.method) \(request.url.path.removingPercentEncoding ?? request.url.path)"
        )
        return try await next.respond(to: request)
    }
}
