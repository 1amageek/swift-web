import Foundation

public enum SwiftWebWasmBuildError: Error, Sendable, CustomStringConvertible {
    case wasmToolchainNotFound(sdkName: String, searched: [String])

    public var description: String {
        switch self {
        case .wasmToolchainNotFound(let sdkName, let searched):
            return """
            Swift WASM toolchain was not found for \(sdkName).
            Install the matching Swift toolchain with wasm-ld, or set SWIFT_WEB_WASM_SWIFT / SWIFT_WEB_WASM_TOOLCHAIN_BIN.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        }
    }
}
