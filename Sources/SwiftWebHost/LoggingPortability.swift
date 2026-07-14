#if !canImport(Logging)
/// Minimal stand-in for swift-log's `Logger`, for profiles built without
/// swift-log (Embedded/wasm core-only builds). Messages go to standard output with a level tag; the
/// embedded host profile (Cloudflare Workers) captures stdout into its log
/// stream. Only the surface the SwiftWeb core uses is provided.
public struct Logger: Sendable {
    public let label: String

    public init(label: String) {
        self.label = label
    }

    public func trace(_ message: @autoclosure () -> String) {
        emit("trace", message())
    }

    public func debug(_ message: @autoclosure () -> String) {
        emit("debug", message())
    }

    public func info(_ message: @autoclosure () -> String) {
        emit("info", message())
    }

    public func notice(_ message: @autoclosure () -> String) {
        emit("notice", message())
    }

    public func warning(_ message: @autoclosure () -> String) {
        emit("warning", message())
    }

    public func error(_ message: @autoclosure () -> String) {
        emit("error", message())
    }

    public func critical(_ message: @autoclosure () -> String) {
        emit("critical", message())
    }

    private func emit(_ level: String, _ message: String) {
        print("[\(label)] \(level): \(message)")
    }
}
#endif
