import HTTPTypes
import SwiftWebCore

/// Stamps every dev-mode worker response with the source fingerprint its
/// executable was built from, so `curl -I` settles any staleness question
/// end to end (docs/DevServerReconcilerDesign.md §6.1). The launcher passes
/// the fingerprint via `SWIFT_WEB_DEV_BUILD_FINGERPRINT`.
final class SwiftWebDevBuildFingerprintMiddleware: Middleware {
    static let headerName = HTTPField.Name("X-SwiftWeb-Dev-Build")!
    static let environmentKey = "SWIFT_WEB_DEV_BUILD_FINGERPRINT"

    private let fingerprint: String

    init(fingerprint: String) {
        self.fingerprint = fingerprint
    }

    convenience init?(environment: [String: String]) {
        guard let digest = environment[Self.environmentKey], !digest.isEmpty else {
            return nil
        }
        self.init(fingerprint: String(digest.prefix(12)))
    }

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers[Self.headerName] = fingerprint
        return response
    }
}
