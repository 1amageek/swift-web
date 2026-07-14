#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftWebCore
import Synchronization

/// Server-side session persistence for the `swift-http-server` host.
/// The default is in-memory; swap the storage for an external store when
/// sessions must survive the process.
public protocol HTTPServerSessionStorage: Sendable {
    func read(_ id: String) -> [String: String]?
    func write(_ id: String, values: [String: String])
    func delete(_ id: String)
}

public final class InMemorySessionStorage: HTTPServerSessionStorage {
    private let sessions = Mutex<[String: [String: String]]>([:])

    public init() {}

    public func read(_ id: String) -> [String: String]? {
        sessions.withLock { $0[id] }
    }

    public func write(_ id: String, values: [String: String]) {
        sessions.withLock { $0[id] = values }
    }

    public func delete(_ id: String) {
        sessions.withLock { $0[id] = nil }
    }
}

/// One request's session: loads lazily from the cookie, creates a session only
/// when a value is written (reading never sets a cookie), and persists /
/// expires the cookie when the response is finalized.
final class HTTPServerSessionBox: Sendable {
    static let cookieName = "swiftweb-session"
    private static let cookieMaxAge = 60 * 60 * 24 * 7

    private struct State {
        var id: String?
        var values: [String: String] = [:]
        var modified = false
        var destroyed = false
    }

    private let state: Mutex<State>
    private let storage: any HTTPServerSessionStorage
    let hasExistingSession: Bool

    init(cookieValue: String?, storage: any HTTPServerSessionStorage) {
        self.storage = storage
        if let cookieValue, let values = storage.read(cookieValue) {
            self.state = Mutex(State(id: cookieValue, values: values))
            self.hasExistingSession = true
        } else {
            self.state = Mutex(State())
            self.hasExistingSession = false
        }
    }

    var webSession: RequestSession {
        RequestSession(
            identifierReader: { self.state.withLock { $0.id } },
            valuesReader: { self.state.withLock { $0.values } },
            valueReader: { key in self.state.withLock { $0.values[key] } },
            valueWriter: { key, value in
                self.state.withLock { state in
                    guard value != nil || state.id != nil || !state.values.isEmpty else {
                        return
                    }
                    state.values[key] = value
                    state.modified = true
                    state.destroyed = false
                }
            },
            destroyHandler: {
                self.state.withLock { state in
                    guard state.id != nil else {
                        state.values.removeAll()
                        state.modified = false
                        return
                    }
                    state.values.removeAll()
                    state.destroyed = true
                    state.modified = false
                }
            }
        )
    }

    /// Persists session changes and appends the matching `Set-Cookie` header.
    func finalize(response: inout Response) {
        let action: (id: String, values: [String: String]?)? = state.withLock { state in
            if state.destroyed, let id = state.id {
                return (id, nil)
            }
            if state.modified {
                let id = state.id ?? Self.generateID()
                state.id = id
                return (id, state.values)
            }
            return nil
        }
        guard let action else {
            return
        }
        if let values = action.values {
            storage.write(action.id, values: values)
            response.setCookie(
                Self.cookieName,
                CookieValue(
                    string: action.id,
                    maxAge: Self.cookieMaxAge,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSite: .lax
                )
            )
        } else {
            storage.delete(action.id)
            response.setCookie(
                Self.cookieName,
                CookieValue(
                    string: "",
                    maxAge: 0,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSite: .lax
                )
            )
        }
    }

    private static func generateID() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
