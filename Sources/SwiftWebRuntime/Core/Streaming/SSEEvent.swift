#if !hasFeature(Embedded)
// SSE/streaming routes decode Codable search params and stream
// over the native host; full profiles only.
public struct SSEEvent: Sendable {
    public let event: String?
    public let id: String?
    public let data: String
    public let retryMilliseconds: Int?

    public init(
        event: String? = nil,
        id: String? = nil,
        data: String,
        retryMilliseconds: Int? = nil
    ) {
        self.event = event
        self.id = id
        self.data = data
        self.retryMilliseconds = retryMilliseconds
    }

    public func render() -> String {
        var output = ""
        if let id {
            output += "id: \(id)\n"
        }
        if let event {
            output += "event: \(event)\n"
        }
        if let retryMilliseconds {
            output += "retry: \(retryMilliseconds)\n"
        }
        for line in data.split(separator: "\n", omittingEmptySubsequences: false) {
            output += "data: \(line)\n"
        }
        output += "\n"
        return output
    }
}
#endif
