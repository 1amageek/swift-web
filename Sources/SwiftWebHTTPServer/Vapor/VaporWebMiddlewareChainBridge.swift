import SwiftWebCore
import Vapor

/// The response a SwiftWeb route handler produced, stashed so the middleware
/// chain reuses it instead of round-tripping (and losing) streaming bodies
/// through the Vapor response conversion.
struct SwiftWebHandledResponseKey: Vapor.StorageKey {
    typealias Value = WebResponse
}

/// Runs the whole SwiftWeb middleware chain (CORS, security, development
/// hooks) as one Vapor middleware. Downstream responses from SwiftWeb routes
/// pass through as their original `WebResponse`; Vapor-native responses
/// (404s, error pages) are converted buffered so the chain can decorate them.
struct VaporWebMiddlewareChainBridge: Vapor.Middleware {
    let chain: WebMiddlewares
    let application: VaporWebApplication

    func respond(to request: Vapor.Request, chainingTo next: any Vapor.Responder) async throws -> Vapor.Response {
        let webRequest = application.webRequest(for: request)
        let terminal = WebClosureResponder { _ in
            let vaporResponse = try await next.respond(to: request)
            if let handled = request.storage[SwiftWebHandledResponseKey.self] {
                request.storage[SwiftWebHandledResponseKey.self] = nil
                return handled
            }
            return VaporWebResponseConversion.bufferedWebResponse(
                from: vaporResponse,
                logger: request.logger
            )
        }
        let webResponse = try await chain.makeResponder(chainingTo: terminal).respond(to: webRequest)
        return VaporWebResponseConversion.vaporResponse(from: webResponse)
    }
}
