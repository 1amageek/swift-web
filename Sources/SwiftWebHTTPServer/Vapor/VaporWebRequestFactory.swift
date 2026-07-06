#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftWebCore
import Vapor

private struct WebRequestStorageKey: Vapor.StorageKey {
    typealias Value = WebRequest
}

extension VaporWebApplication {
    /// Returns the host-neutral request for a Vapor request, creating it on
    /// first access. Middleware and the route handler share the same instance,
    /// so request-scoped state (security context, path parameters) propagates.
    public func webRequest(for request: Vapor.Request) -> WebRequest {
        if let existing = request.storage[WebRequestStorageKey.self] {
            return existing
        }
        let webRequest = WebRequest(
            method: request.method,
            url: WebURL(
                string: request.url.string,
                scheme: request.url.scheme,
                host: request.url.host,
                path: request.url.path,
                query: request.url.query
            ),
            headers: request.headers,
            cookies: request.cookies.all.mapValues(\.string),
            query: WebQueryContainer { type in
                try request.query.decode(type)
            },
            content: WebContentContainer(
                decoder: { type in
                    try await request.content.decode(type)
                },
                fieldDecoder: { type, name in
                    if type == WebFile.self {
                        let file = try await request.content.get(Vapor.File.self, at: name)
                        return WebFile(
                            data: Array(file.data.readableBytesView),
                            filename: file.filename,
                            contentType: file.contentType.map { "\($0)" }
                        )
                    }
                    return try await request.content.get(type, at: name)
                }
            ),
            collectBody: {
                request.body.data.map { Array($0.readableBytesView) }
            },
            session: .vapor(request),
            hasSession: request.hasSession,
            logger: request.logger,
            application: self,
            remoteAddress: request.remoteAddress?.ipAddress
        )
        request.storage[WebRequestStorageKey.self] = webRequest
        return webRequest
    }
}

extension WebSession {
    static func vapor(_ request: Vapor.Request) -> WebSession {
        WebSession(
            identifierReader: {
                guard request.hasSession else {
                    return nil
                }
                return request.session.id?.string
            },
            valuesReader: {
                guard request.hasSession else {
                    return [:]
                }
                return request.session.data.snapshot
            },
            valueReader: { key in
                guard request.hasSession else {
                    return nil
                }
                return request.session.data[key]
            },
            valueWriter: { key, value in
                guard value != nil || request.hasSession else {
                    return
                }
                var data = request.session.data
                data[key] = value
                request.session.data = data
            },
            destroyHandler: {
                guard request.hasSession else {
                    return
                }
                let session = request.session
                session.data = SessionData()
                session.destroy()
            }
        )
    }
}
