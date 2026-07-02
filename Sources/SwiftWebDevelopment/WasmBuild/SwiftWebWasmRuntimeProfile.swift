import Foundation

public enum SwiftWebWasmRuntimeProfile: String, Sendable, Equatable {
    case standard
    case embedded

    public static func defaultValue(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SwiftWebWasmRuntimeProfile {
        _ = environment
        return .standard
    }
}
