public enum SwiftPMWasmArtifactError: Error, CustomStringConvertible {
    case packageRootNotFound(String)

    public var description: String {
        switch self {
        case .packageRootNotFound(let path):
            "Package.swift was not found while walking up from \(path)"
        }
    }
}
