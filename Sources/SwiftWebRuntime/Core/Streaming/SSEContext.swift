
public struct SSEContext<SearchParams: Decodable & Sendable>: Sendable {
    public let request: Request
    public let searchParams: SearchParams

    public init(request: Request, searchParams: SearchParams) {
        self.request = request
        self.searchParams = searchParams
    }
}
