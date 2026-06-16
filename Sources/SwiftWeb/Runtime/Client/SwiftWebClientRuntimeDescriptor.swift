import SwiftHTML

public struct SwiftWebClientRuntimeDescriptor: Sendable, Codable, Equatable {
    public let mode: SwiftWebClientRuntimeDescriptorMode
    public let hydrationIndex: BrowserHydrationIndex
    public let manifest: ClientBundleManifest?
    public let wasm: SwiftWebWasmClientRuntime?
    public let security: ClientSecurityDescriptor?

    public init(
        mode: SwiftWebClientRuntimeDescriptorMode,
        hydrationIndex: BrowserHydrationIndex,
        manifest: ClientBundleManifest? = nil,
        wasm: SwiftWebWasmClientRuntime? = nil,
        security: ClientSecurityDescriptor? = nil
    ) {
        self.mode = mode
        self.hydrationIndex = hydrationIndex
        self.manifest = manifest
        self.wasm = wasm
        self.security = security
    }
}

public enum SwiftWebClientRuntimeDescriptorMode: String, Sendable, Codable, Equatable {
    case wasm
}
