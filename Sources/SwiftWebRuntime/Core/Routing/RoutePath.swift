import SwiftWebHost

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

    public var webComponents: [PathComponent] {
        components.map { PathComponent($0) }
    }

    public var string: String {
        "/" + components.joined(separator: "/")
    }
}
