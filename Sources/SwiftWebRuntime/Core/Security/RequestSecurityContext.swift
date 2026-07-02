import Vapor

public struct RequestSecurityContext: Sendable, Equatable {
    public let csrfToken: String?
    public let csrfFieldName: String?
    public let cspNonce: String?

    let shouldSetCSRFCookie: Bool

    public init(
        csrfToken: String? = nil,
        csrfFieldName: String? = nil,
        cspNonce: String? = nil,
        shouldSetCSRFCookie: Bool = false
    ) {
        self.csrfToken = csrfToken
        self.csrfFieldName = csrfFieldName
        self.cspNonce = cspNonce
        self.shouldSetCSRFCookie = shouldSetCSRFCookie
    }
}

private struct RequestSecurityContextStorageKey: StorageKey {
    typealias Value = RequestSecurityContext
}

extension Request {
    var securityContext: RequestSecurityContext? {
        get {
            storage[RequestSecurityContextStorageKey.self]
        }
        set {
            var currentStorage = storage
            currentStorage[RequestSecurityContextStorageKey.self] = newValue
            storage = currentStorage
        }
    }
}
