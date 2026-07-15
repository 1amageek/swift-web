import HTTPTypes
import Testing
@testable import SwiftWebCore

@Suite
struct CachePolicyTests {
    @Test
    func noneEmitsNoHeader() {
        #expect(CachePolicy.none.headerValue.isEmpty)
        let response = Response().cache(.none)
        #expect(response.headers[.cacheControl] == nil)
    }

    @Test
    func noStoreEmitsNoStore() {
        #expect(CachePolicy.noStore.headerValue == "no-store")
        let response = Response().cache(.noStore)
        #expect(response.headers[.cacheControl] == "no-store")
    }

    @Test
    func privateCacheEmitsPrivateMaxAge() {
        #expect(CachePolicy.privateCache(seconds: 60).headerValue == "private, max-age=60")
    }

    @Test
    func publicCacheEmitsPublicMaxAge() {
        #expect(CachePolicy.publicCache(seconds: 3600).headerValue == "public, max-age=3600")
    }

    @Test
    func publicCacheWithSharedLifetimeEmitsSMaxage() {
        let policy = CachePolicy.publicCache(browserSeconds: 600, sharedSeconds: 172_800)
        #expect(policy.headerValue == "public, max-age=600, s-maxage=172800")
    }

    @Test
    func equatableDistinguishesLifetimes() {
        #expect(CachePolicy.publicCache(seconds: 60) == CachePolicy.publicCache(seconds: 60))
        #expect(CachePolicy.publicCache(seconds: 60) != CachePolicy.publicCache(seconds: 61))
        #expect(
            CachePolicy.publicCache(seconds: 60)
                != CachePolicy.publicCache(browserSeconds: 60, sharedSeconds: 60)
        )
        #expect(CachePolicy.none != CachePolicy.noStore)
    }
}
