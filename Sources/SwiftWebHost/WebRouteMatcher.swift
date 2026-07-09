import HTTPTypes

public struct WebRouteMatch: Sendable {
    public let route: WebRoute
    public let parameters: WebPathParameters

    public init(route: WebRoute, parameters: WebPathParameters) {
        self.route = route
        self.parameters = parameters
    }
}

/// Matches requests against a collected `WebRoute` table, replacing
/// `routing-kit` for hosts without a native router (swift-http-server,
/// Cloudflare Workers).
///
/// Specificity follows the conventional trie priority per component:
/// constant > parameter > anything > catchall.
public struct WebRouteMatcher: Sendable {
    private let routes: [WebRoute]

    public init(routes: [WebRoute]) {
        self.routes = routes
    }

    public func match(method: HTTPRequest.Method, path: String) -> WebRouteMatch? {
        let components = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        return match(method: method, pathComponents: components)
    }

    public func match(method: HTTPRequest.Method, pathComponents: [String]) -> WebRouteMatch? {
        var best: (route: WebRoute, parameters: WebPathParameters, specificity: [Int])?
        for route in routes {
            guard route.method == method || (method == .head && route.method == .get) else {
                continue
            }
            guard let (parameters, specificity) = Self.match(route.path, against: pathComponents) else {
                continue
            }
            if let current = best, !Self.isMoreSpecific(specificity, than: current.specificity) {
                continue
            }
            best = (route, parameters, specificity)
        }
        return best.map { WebRouteMatch(route: $0.route, parameters: $0.parameters) }
    }

    private static func match(
        _ pattern: [WebPathComponent],
        against components: [String]
    ) -> (WebPathParameters, specificity: [Int])? {
        var parameters = WebPathParameters()
        var specificity: [Int] = []
        var index = 0
        for (patternIndex, component) in pattern.enumerated() {
            switch component {
            case .constant(let value):
                guard index < components.count, components[index] == value else {
                    return nil
                }
                specificity.append(3)
                index += 1
            case .parameter(let name):
                guard index < components.count else {
                    return nil
                }
                parameters.set(name, to: components[index])
                specificity.append(2)
                index += 1
            case .anything:
                guard index < components.count else {
                    return nil
                }
                specificity.append(1)
                index += 1
            case .catchall:
                // Catchall must be terminal; it consumes the remainder (possibly empty).
                guard patternIndex == pattern.count - 1 else {
                    return nil
                }
                specificity.append(0)
                index = components.count
            }
        }
        guard index == components.count else {
            return nil
        }
        return (parameters, specificity)
    }

    /// Lexicographic comparison of per-component specificity; longer (more
    /// constrained) patterns win ties so `/a/b` beats `/a/**`.
    private static func isMoreSpecific(_ lhs: [Int], than rhs: [Int]) -> Bool {
        for (left, right) in zip(lhs, rhs) where left != right {
            return left > right
        }
        return lhs.count > rhs.count
    }
}
