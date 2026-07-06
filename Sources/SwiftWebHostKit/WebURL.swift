/// The pieces of the request URL the SwiftWeb core reads.
/// Host adapters populate it from their native request.
public struct WebURL: Sendable, Equatable {
    /// The full URL string (or path + query for host runtimes without an origin).
    public let string: String
    public let scheme: String?
    public let host: String?
    public let path: String
    public let query: String?

    public init(
        string: String,
        scheme: String? = nil,
        host: String? = nil,
        path: String,
        query: String? = nil
    ) {
        self.string = string
        self.scheme = scheme
        self.host = host
        self.path = path
        self.query = query
    }
}
