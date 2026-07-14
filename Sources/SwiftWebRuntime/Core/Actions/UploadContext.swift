#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.

public struct UploadContext<Params: Decodable & Sendable, Input: Decodable & Sendable>: Sendable {
    public let request: Request
    public let params: Params
    public let input: Input

    public init(request: Request, params: Params, input: Input) {
        self.request = request
        self.params = params
        self.input = input
    }

    public func file(_ name: String) async throws -> File {
        try await request.content.get(File.self, at: name)
    }
}
#endif
