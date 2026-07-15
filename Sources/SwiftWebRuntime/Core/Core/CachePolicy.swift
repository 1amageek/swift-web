import HTTPTypes

/// A page's HTTP caching contract, emitted as the `Cache-Control` header.
///
/// Modeled as the closed set of valid directive combinations (kept in a
/// private storage enum) behind static factories: contradictory states
/// (`private` + `s-maxage`, `no-store` + `max-age`) cannot be constructed,
/// and new combinations can be added without breaking exhaustive switches
/// in downstream code.
public struct CachePolicy: Equatable, Sendable {
    private enum Directives: Equatable, Sendable {
        case unspecified
        case noStore
        case privateCache(maxAge: Int)
        case publicCache(maxAge: Int, sharedMaxAge: Int?)
    }

    private let directives: Directives

    /// Emits no `Cache-Control` header; caches apply their heuristics.
    public static let none = CachePolicy(directives: .unspecified)

    /// `no-store`: the response must not be stored by any cache.
    public static let noStore = CachePolicy(directives: .noStore)

    /// `private, max-age=seconds`: only the browser may cache the response;
    /// shared caches (CDN edges, proxies) must not store it.
    public static func privateCache(seconds: Int) -> CachePolicy {
        CachePolicy(directives: .privateCache(maxAge: seconds))
    }

    /// `public, max-age=seconds`: browsers and shared caches store the
    /// response with the same freshness lifetime.
    public static func publicCache(seconds: Int) -> CachePolicy {
        CachePolicy(directives: .publicCache(maxAge: seconds, sharedMaxAge: nil))
    }

    /// `public, max-age=browserSeconds, s-maxage=sharedSeconds`: shared
    /// caches keep the response longer than browsers. Use when an edge cache
    /// can be invalidated on demand (by key or purge) while browser copies
    /// cannot — the short browser lifetime bounds how long users can be
    /// served a page that a new deploy has already replaced.
    public static func publicCache(browserSeconds: Int, sharedSeconds: Int) -> CachePolicy {
        CachePolicy(directives: .publicCache(maxAge: browserSeconds, sharedMaxAge: sharedSeconds))
    }

    /// The `Cache-Control` field value; empty for `.none` (no header).
    public var headerValue: String {
        switch directives {
        case .unspecified:
            return ""
        case .noStore:
            return "no-store"
        case .privateCache(let maxAge):
            return "private, max-age=\(maxAge)"
        case .publicCache(let maxAge, let sharedMaxAge):
            guard let sharedMaxAge else {
                return "public, max-age=\(maxAge)"
            }
            return "public, max-age=\(maxAge), s-maxage=\(sharedMaxAge)"
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
