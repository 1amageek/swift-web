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

    public var defaultSwiftSDKName: String {
        switch self {
        case .standard:
            SwiftWebWasmToolchain.defaultSwiftSDKName
        case .embedded:
            SwiftWebWasmToolchain.defaultEmbeddedSwiftSDKName
        }
    }

    public func supports(swiftSDKName: String) -> Bool {
        swiftSDKName == defaultSwiftSDKName
    }
}
