enum ClientRuntimeJSONCodecError: Error, Sendable, CustomStringConvertible {
    case invalidValue(path: String, expected: String)
    case malformedJSON(offset: Int)
    case nestingLimitExceeded(Int)
    case unsupportedValue(path: String, value: String)

    var description: String {
        switch self {
        case .invalidValue(let path, let expected):
            "Invalid client runtime JSON value at \(path); expected \(expected)"
        case .malformedJSON(let offset):
            "Malformed client runtime JSON at byte offset \(offset)"
        case .nestingLimitExceeded(let maximumDepth):
            "Client runtime JSON exceeds the nesting limit of \(maximumDepth)"
        case .unsupportedValue(let path, let value):
            "Unsupported client runtime JSON value at \(path): \(value)"
        }
    }
}
