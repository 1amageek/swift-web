/// Path parameters captured by the host router for a matched route
/// (e.g. `:id` in `/blog/:id`). Values are percent-decoded by the matcher
/// before they are stored, so handlers always see the real value.
public struct PathParameters: Sendable, RequestParameters {
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

    public func rawValue(_ name: String) -> String? {
        storage[name]
    }

    public func rawValues(_ name: String) -> [String] {
        storage[name].map { [$0] } ?? []
    }
}
