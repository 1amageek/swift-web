/// A value that can render itself as a host-neutral response.
public protocol ResponseEncodable {
    func encodeResponse(for request: Request) async throws -> Response
}
