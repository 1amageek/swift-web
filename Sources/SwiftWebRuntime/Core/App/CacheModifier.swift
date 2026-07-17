import SwiftHTML

/// The cache policy pages inherit when they do not declare one.
struct PageCachePolicyKey: EnvironmentKey {
    static let defaultValue: CachePolicy = .none
}

extension EnvironmentValues {
    /// The cache policy a page inherits when its `cache` requirement is
    /// unspecified (``CachePolicy/none``). Set through ``Scene/cache(_:)``.
    public var pageCachePolicy: CachePolicy {
        get { self[PageCachePolicyKey.self] }
        set { self[PageCachePolicyKey.self] = newValue }
    }
}

extension Scene {
    /// Declares the cache policy for every page in the hierarchy below.
    ///
    /// A page that declares its own `cache` keeps it; a page whose `cache`
    /// is unspecified inherits this one. `CachePolicy.none` means
    /// "unspecified" — a page inside a cached group opts out of caching by
    /// declaring an explicit policy such as ``CachePolicy/noStore``, not by
    /// returning `.none`.
    ///
    ///     PageGroup {
    ///         HomePage()
    ///         DetailPage()
    ///     }
    ///     .cache(.publicCache(browserSeconds: 600, sharedSeconds: 172_800))
    public func cache(_ policy: CachePolicy) -> some Scene {
        transformEnvironment { $0.pageCachePolicy = policy }
    }
}
