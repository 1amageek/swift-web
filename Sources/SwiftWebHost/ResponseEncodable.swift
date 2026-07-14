/// A value that can render itself as a host-neutral response,
/// replacing `Vapor.ResponseEncodable` for the SwiftWeb core.
public protocol ResponseEncodable {
    func encodeResponse(for request: Request) async throws -> Response
}
