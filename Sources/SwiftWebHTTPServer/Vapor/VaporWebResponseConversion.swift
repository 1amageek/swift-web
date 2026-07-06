#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import NIOCore
import SwiftWebCore
import Vapor

enum VaporWebResponseConversion {
    static func vaporResponse(from response: WebResponse) -> Vapor.Response {
        let body: Vapor.Response.Body
        if let produce = response.body.stream {
            body = .init(managedAsyncStream: { writer in
                try await produce(VaporWebBodyWriter(writer: writer))
            })
        } else if let bytes = response.body.bytes, !bytes.isEmpty {
            body = .init(data: Data(bytes))
        } else {
            body = .empty
        }
        return Vapor.Response(status: response.status, headers: response.headers, body: body)
    }

    /// Converts a Vapor-native response (404s, error pages) for the SwiftWeb
    /// middleware chain. Such responses are buffered; a streaming body here
    /// means a non-SwiftWeb route streamed, which the bridge cannot carry —
    /// surface it loudly instead of truncating silently.
    static func bufferedWebResponse(from response: Vapor.Response, logger: Logger) -> WebResponse {
        let bytes: [UInt8]
        if let data = response.body.data {
            bytes = Array(data)
        } else {
            if response.body.count != 0 {
                logger.error("SwiftWeb middleware bridge dropped a streaming body of a non-SwiftWeb response; register streaming routes through SwiftWeb scenes instead")
            }
            bytes = []
        }
        return WebResponse(
            status: response.status,
            headers: response.headers,
            body: .init(bytes: bytes)
        )
    }
}

struct VaporWebBodyWriter: WebBodyWriter {
    let writer: any Vapor.AsyncBodyStreamWriter

    func write(_ bytes: [UInt8]) async throws {
        try await writer.write(.buffer(ByteBuffer(bytes: bytes)))
    }
}
