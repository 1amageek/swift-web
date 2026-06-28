public enum ClientRuntimeEntrypointError: Error, CustomStringConvertible {
    case invalidInputPointer

    public var description: String {
        switch self {
        case .invalidInputPointer:
            "Input pointer is invalid"
        }
    }
}
