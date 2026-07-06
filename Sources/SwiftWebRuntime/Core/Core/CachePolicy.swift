import HTTPTypes

public enum CachePolicy: Equatable, Sendable {
    case none
    case publicCache(seconds: Int)
    case privateCache(seconds: Int)
    case noStore

    public var headerValue: String {
        switch self {
        case .none:
            return ""
        case .publicCache(let seconds):
            return "public, max-age=\(seconds)"
        case .privateCache(let seconds):
            return "private, max-age=\(seconds)"
        case .noStore:
            return "no-store"
        }
    }
}

extension Response {
    public func cache(_ policy: CachePolicy) -> Response {
        guard policy != .none else {
            return self
        }
        var response = self
        response.headers[.cacheControl] = policy.headerValue
        return response
    }
}
