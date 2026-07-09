#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

/// The host-neutral HTTP response the SwiftWeb core produces.
/// Host adapters (Vapor, swift-http-server, Cloudflare) lower it onto their
/// native response type.
public struct WebResponse: Sendable {
    public struct Body: Sendable {
        enum Storage: Sendable {
            case none
            case bytes([UInt8])
            case stream(@Sendable (any WebBodyWriter) async throws -> Void)
        }

        let storage: Storage

        public static let empty = Body(storage: .none)

        public init(bytes: [UInt8]) {
            self.init(storage: .bytes(bytes))
        }

        public init(string: String) {
            self.init(storage: .bytes(Array(string.utf8)))
        }

        public init(data: Data) {
            self.init(storage: .bytes(Array(data)))
        }

        /// A streaming body produced incrementally. The host adapter closes the
        /// stream when the closure returns and fails the response when it throws.
        public init(managedAsyncStream: @escaping @Sendable (any WebBodyWriter) async throws -> Void) {
            self.init(storage: .stream(managedAsyncStream))
        }

        init(storage: Storage) {
            self.storage = storage
        }

        /// The buffered bytes, or `nil` for streaming bodies.
        public var bytes: [UInt8]? {
            switch storage {
            case .none:
                []
            case .bytes(let bytes):
                bytes
            case .stream:
                nil
            }
        }

        /// The buffered body decoded as UTF-8, or `nil` for streaming bodies.
        public var string: String? {
            bytes.map { String(decoding: $0, as: UTF8.self) }
        }

        /// The streaming producer, or `nil` for buffered bodies.
        public var stream: (@Sendable (any WebBodyWriter) async throws -> Void)? {
            switch storage {
            case .none, .bytes:
                nil
            case .stream(let produce):
                produce
            }
        }
    }

    public var status: HTTPResponse.Status
    public var headers: HTTPFields
    public var body: Body

    public init(
        status: HTTPResponse.Status = .ok,
        headers: HTTPFields = [:],
        body: Body = .empty
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Appends a `Set-Cookie` header for the given cookie.
    public mutating func setCookie(_ name: String, _ value: WebHTTPCookieValue) {
        headers.append(HTTPField(name: .setCookie, value: value.serialized(name: name)))
    }

    public static func redirect(
        to location: String,
        status: HTTPResponse.Status = .seeOther
    ) -> WebResponse {
        var headers = HTTPFields()
        headers[.location] = location
        return WebResponse(status: status, headers: headers)
    }
}
