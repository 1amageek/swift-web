import Foundation

public enum SwiftWebWasmSplitBuildStrategy: Sendable, Equatable {
    case resolvedBundles
    case coalescedPolicyBundles

    public static func defaultValue(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SwiftWebWasmSplitBuildStrategy {
        guard let rawValue = environment["SWIFTWEB_WASM_SPLIT_BUILD_STRATEGY"] else {
            return .coalescedPolicyBundles
        }

        switch rawValue.lowercased() {
        case "coalesced", "coalesced-policy", "coalesced-policies", "coalesced-deferred", "coalesced-static":
            return .coalescedPolicyBundles
        case "resolved", "resolved-bundles", "standalone":
            return .resolvedBundles
        default:
            return .coalescedPolicyBundles
        }
    }
}
