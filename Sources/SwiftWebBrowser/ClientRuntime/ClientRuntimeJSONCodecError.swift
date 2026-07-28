enum ClientRuntimeJSONCodecError: Error, Sendable, CustomStringConvertible {
    case invalidValue(path: String, expected: String)
    case unsupportedValue(path: String, value: String)

    var description: String {
        switch self {
        case .invalidValue(let path, let expected):
            "Invalid client runtime JSON value at \(path); expected \(expected)"
        case .unsupportedValue(let path, let value):
            "Unsupported client runtime JSON value at \(path): \(value)"
        }
    }
}
