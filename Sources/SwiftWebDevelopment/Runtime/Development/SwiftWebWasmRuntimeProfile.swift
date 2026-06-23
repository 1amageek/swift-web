import Foundation

public enum SwiftWebWasmRuntimeProfile: String, Sendable, Equatable {
    case standard
    case embedded

    public static func defaultValue(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SwiftWebWasmRuntimeProfile {
        guard let rawValue = environment["SWIFTWEB_WASM_RUNTIME_PROFILE"], !rawValue.isEmpty else {
            return .standard
        }
        return SwiftWebWasmRuntimeProfile(rawValue: rawValue) ?? .standard
    }
}
