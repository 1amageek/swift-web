import HTTPTypes

/// A host-neutral error carrying an HTTP status, thrown by SwiftWeb handlers.
/// Host adapters map it onto their native error response.
public struct Abort: Error, Sendable, CustomStringConvertible {
    public let status: HTTPResponse.Status
    public let reason: String?

    public init(_ status: HTTPResponse.Status, reason: String? = nil) {
        self.status = status
        self.reason = reason
    }

    public var description: String {
        if let reason {
            "Abort(\(status.code): \(reason))"
        } else {
            "Abort(\(status.code))"
        }
    }
}
