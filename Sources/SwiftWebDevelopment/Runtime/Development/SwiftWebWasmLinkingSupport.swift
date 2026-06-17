import Foundation

public struct SwiftWebWasmLinkingSupport: Sendable, Equatable {
    public let supportsThinComponentModules: Bool
    public let recommendedSplitBuildStrategy: SwiftWebWasmSplitBuildStrategy
    public let reason: String

    public init(
        supportsThinComponentModules: Bool,
        recommendedSplitBuildStrategy: SwiftWebWasmSplitBuildStrategy,
        reason: String
    ) {
        self.supportsThinComponentModules = supportsThinComponentModules
        self.recommendedSplitBuildStrategy = recommendedSplitBuildStrategy
        self.reason = reason
    }

    public static func evaluate(
        sdkName: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SwiftWebWasmLinkingSupport {
        if environment["SWIFTWEB_WASM_THIN_COMPONENT_MODULES"] == "1" {
            return SwiftWebWasmLinkingSupport(
                supportsThinComponentModules: true,
                recommendedSplitBuildStrategy: .resolvedBundles,
                reason: "Thin component modules were explicitly enabled by the environment."
            )
        }

        if sdkName.contains("wasm") {
            return SwiftWebWasmLinkingSupport(
                supportsThinComponentModules: false,
                recommendedSplitBuildStrategy: .coalescedPolicyBundles,
                reason: "The current Swift/WASI toolchain does not expose a stable browser-ready dynamic component module contract."
            )
        }

        return SwiftWebWasmLinkingSupport(
            supportsThinComponentModules: false,
            recommendedSplitBuildStrategy: .resolvedBundles,
            reason: "The selected SDK is not a WebAssembly SDK."
        )
    }
}
