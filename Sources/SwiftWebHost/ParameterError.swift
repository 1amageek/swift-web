/// A request parameter failed to bind to the Swift type a route declared.
/// Hosts surface it as `400 Bad Request`; the associated values name the
/// offending parameter so the client can correct the request.
public enum ParameterError: Error, Sendable, Equatable {
    case missing(name: String)
    case invalid(name: String, value: String, type: String)

    public var message: String {
        switch self {
        case .missing(let name):
            "missing required parameter '\(name)'"
        case .invalid(let name, let value, let type):
            "parameter '\(name)' value '\(value)' is not a valid \(type)"
        }
    }
}
