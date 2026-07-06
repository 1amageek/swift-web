/// A value that can render itself as a host-neutral response,
/// replacing `Vapor.ResponseEncodable` for the SwiftWeb core.
public protocol WebResponseEncodable {
    func encodeResponse(for request: WebRequest) async throws -> WebResponse
}
