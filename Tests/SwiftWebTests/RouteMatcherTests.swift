import HTTPTypes
import Testing
@testable import SwiftWebCore

@Suite
struct RouteMatcherTests {
    @Test
    func matchesConstantAndParameterRoutes() throws {
        let routes = Routes()
        routes.get(["blog"]) { _ in Response() }
        routes.get(["blog", ":id"]) { _ in Response() }
        let matcher = RouteMatcher(routes: routes.all)

        let index = try #require(matcher.match(method: .get, path: "/blog"))
        #expect(index.parameters.get("id") == nil)

        let detail = try #require(matcher.match(method: .get, path: "/blog/42"))
        #expect(detail.parameters.get("id") == "42")

        #expect(matcher.match(method: .post, path: "/blog") == nil)
        #expect(matcher.match(method: .get, path: "/blog/42/extra") == nil)
    }

    @Test
    func prefersConstantOverParameterOverCatchall() throws {
        let routes = Routes()
        let constant = routes.get(["docs", "index"]) { _ in Response() }
        let parameter = routes.get(["docs", ":page"]) { _ in Response() }
        let catchall = routes.get(["docs", "**"]) { _ in Response() }
        let matcher = RouteMatcher(routes: routes.all)

        #expect(matcher.match(method: .get, path: "/docs/index")?.route === constant)
        #expect(matcher.match(method: .get, path: "/docs/intro")?.route === parameter)
        #expect(matcher.match(method: .get, path: "/docs/a/b/c")?.route === catchall)
    }

    @Test
    func matchesRootAndHeadFallsBackToGet() throws {
        let routes = Routes()
        let root = routes.get([]) { _ in Response() }
        let matcher = RouteMatcher(routes: routes.all)

        #expect(matcher.match(method: .get, path: "/")?.route === root)
        #expect(matcher.match(method: .head, path: "/")?.route === root)
    }
}
