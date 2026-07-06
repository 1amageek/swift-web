import HTTPTypes

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
                ?? configuredHost(for: request)
        } else {
            request.headers[HTTPField.Name("Host")!] ?? request.url.host ?? configuredHost(for: request)
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
            guard let remoteAddress = request.remoteAddress else {
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

    private func configuredHost(for request: Request) -> String? {
        guard let hostname = request.application.serverConfiguration.hostname else {
            return nil
        }
        guard let port = request.application.serverConfiguration.port else {
            return hostname
        }
        return "\(hostname):\(port)"
    }
}
