import HTTPTypes
import Vapor

public enum ForwardedHeadersPolicy: Sendable {
    case ignore
    case trust
    case trustedProxies(Set<String>)

    func scheme(for request: Request) -> String? {
        if shouldTrustForwardedHeaders(for: request) {
            firstHeaderValue(request.headers[HTTPField.Name("X-Forwarded-Proto")!]) ?? request.url.scheme
        } else {
            request.url.scheme
        }
    }

    func host(for request: Request) -> String? {
        if shouldTrustForwardedHeaders(for: request) {
            firstHeaderValue(request.headers[HTTPField.Name("X-Forwarded-Host")!])
                ?? request.headers[HTTPField.Name("Host")!]
                ?? request.url.host
        } else {
            request.headers[HTTPField.Name("Host")!] ?? request.url.host
        }
    }

    func isSecure(_ request: Request) -> Bool {
        guard shouldTrustForwardedHeaders(for: request) else {
            return request.url.scheme == "https"
        }
        return request.url.scheme == "https"
            || firstHeaderValue(request.headers[HTTPField.Name("X-Forwarded-Proto")!]) == "https"
    }

    private func shouldTrustForwardedHeaders(for request: Request) -> Bool {
        switch self {
        case .ignore:
            return false
        case .trust:
            return true
        case .trustedProxies(let addresses):
            guard let remoteAddress = request.remoteAddress?.ipAddress else {
                return false
            }
            return addresses.contains(remoteAddress)
        }
    }

    private func firstHeaderValue(_ value: String?) -> String? {
        value?
            .split(separator: ",", maxSplits: 1)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
