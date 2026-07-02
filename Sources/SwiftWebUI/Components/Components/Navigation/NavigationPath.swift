import SwiftWebUITheme

/// The navigation state of a URL-backed `NavigationStack`: the ordered URL
/// path segments below the stack's base route.
///
/// Appending a segment navigates deeper; removing segments navigates back.
/// The runtime lowers path writes into same-origin document transitions — see
/// `docs/ClientNavigationDesign.md` ("URL-Backed NavigationStack").
public struct NavigationPath: Codable, Sendable, Equatable, ExpressibleByArrayLiteral {
    public private(set) var components: [String]

    public init(_ components: [String] = []) {
        for component in components {
            Self.validate(component)
        }
        self.components = components
    }

    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }

    public var count: Int {
        components.count
    }

    public var isEmpty: Bool {
        components.isEmpty
    }

    public mutating func append(_ component: String) {
        Self.validate(component)
        components.append(component)
    }

    public mutating func removeLast(_ k: Int = 1) {
        precondition(
            k >= 0 && k <= components.count,
            "Cannot remove \(k) components from a navigation path with \(components.count)"
        )
        components.removeLast(k)
    }

    private static func validate(_ component: String) {
        precondition(
            !component.isEmpty
                && !component.contains("/")
                && !component.contains("?")
                && !component.contains("#"),
            "NavigationPath components are URL path segments; \"\(component)\" is not a valid segment"
        )
    }
}
