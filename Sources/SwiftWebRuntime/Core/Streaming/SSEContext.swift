#if !hasFeature(Embedded)
// SSE/streaming routes decode Codable search params and stream
// over the native host; full profiles only.

public struct SSEContext<SearchParams: Decodable & Sendable>: Sendable {
    public let request: Request
    public let searchParams: SearchParams

    public init(request: Request, searchParams: SearchParams) {
        self.request = request
        self.searchParams = searchParams
    }
}
#endif
