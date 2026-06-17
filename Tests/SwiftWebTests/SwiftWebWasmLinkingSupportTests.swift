@testable import SwiftWebDevelopment
import Testing

@Suite
struct SwiftWebWasmLinkingSupportTests {
    @Test
    func recommendsCoalescedFallbackForCurrentWasmSDK() {
        let support = SwiftWebWasmLinkingSupport.evaluate(
            sdkName: "swift-6.3.1-RELEASE_wasm",
            environment: [:]
        )

        #expect(!support.supportsThinComponentModules)
        #expect(support.recommendedSplitBuildStrategy == .coalescedPolicyBundles)
    }

    @Test
    func allowsExplicitThinModuleOverride() {
        let support = SwiftWebWasmLinkingSupport.evaluate(
            sdkName: "swift-6.3.1-RELEASE_wasm",
            environment: ["SWIFTWEB_WASM_THIN_COMPONENT_MODULES": "1"]
        )

        #expect(support.supportsThinComponentModules)
        #expect(support.recommendedSplitBuildStrategy == .resolvedBundles)
    }

    @Test
    func readsCoalescedStrategyFromEnvironment() {
        let strategy = SwiftWebWasmSplitBuildStrategy.defaultValue(
            environment: ["SWIFTWEB_WASM_SPLIT_BUILD_STRATEGY": "coalesced-static"]
        )

        #expect(strategy == .coalescedPolicyBundles)
    }

    @Test
    func defaultsToCoalescedStrategyForCurrentToolchainSafety() {
        #expect(SwiftWebWasmSplitBuildStrategy.defaultValue(environment: [:]) == .coalescedPolicyBundles)
    }
}
