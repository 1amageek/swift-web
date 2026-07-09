/// Path parameters captured by the host router for a matched route
/// (e.g. `:id` in `/blog/:id`).
public struct WebPathParameters: Sendable {
    private var storage: [String: String]

    public init(_ storage: [String: String] = [:]) {
        self.storage = storage
    }

    public func get(_ name: String) -> String? {
        storage[name]
    }

    public mutating func set(_ name: String, to value: String) {
        storage[name] = value
    }
}
