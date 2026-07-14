/// How the host collects the request body before invoking a route handler.
public enum BodyStreamStrategy: Sendable {
    /// Buffer the body up to `maxSize` bytes (host default when `nil`) before the handler runs.
    case collect(maxSize: Int?)
    /// Hand the body to the handler as it streams in.
    case stream

    public static let collect = BodyStreamStrategy.collect(maxSize: nil)
}
