#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
import HTTPTypes
import SwiftHTML

public enum ServerActionMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"

    public var formMethod: FormMethod {
        switch self {
        case .get:
            .get
        case .post, .put, .delete:
            .post
        }
    }

    var httpMethod: HTTPRequest.Method {
        switch self {
        case .get:
            .get
        case .post:
            .post
        case .put:
            .put
        case .delete:
            .delete
        }
    }

    var requiresFormMethodOverride: Bool {
        switch self {
        case .get, .post:
            false
        case .put, .delete:
            true
        }
    }
}
#endif

#if !hasFeature(Embedded)
extension ServerActionMethod: Codable {}
#endif
