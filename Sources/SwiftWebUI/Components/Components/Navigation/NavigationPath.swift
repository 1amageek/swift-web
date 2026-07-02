import SwiftWebUITheme
public struct NavigationPath: Codable, Sendable, Equatable, ExpressibleByArrayLiteral {
    public var components: [String]

    public init(_ components: [String] = []) {
        self.components = components
    }

    public init(arrayLiteral elements: String...) {
        self.components = elements
    }

    public mutating func append(_ component: String) {
        components.append(component)
    }

    public mutating func removeLast() {
        _ = components.popLast()
    }
}
