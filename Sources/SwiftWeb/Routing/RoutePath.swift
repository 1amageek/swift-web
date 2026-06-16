import RoutingKit

public struct RoutePath: Sendable {
    public let components: [String]

    public init(_ path: String) {
        self.components = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }

    public init(_ components: [String]) {
        self.components = components
    }

    var vaporComponents: [PathComponent] {
        components.map { PathComponent(stringLiteral: $0) }
    }

    public var string: String {
        "/" + components.joined(separator: "/")
    }
}
