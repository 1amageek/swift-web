import Foundation

public enum SwiftWebHostToolchainError: Error, Sendable, CustomStringConvertible {
    case hostSwiftToolchainNotFound(searched: [String])

    public var description: String {
        switch self {
        case .hostSwiftToolchainNotFound(let searched):
            return """
            Swift host toolchain was not found.
            Set SWIFT_WEB_HOST_SWIFT to a swift executable, or set SWIFT_WEB_HOST_TOOLCHAIN_BIN to a toolchain bin directory.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        }
    }
}
