import SwiftHTML
import SwiftWebActors

public struct SwiftWebClientRuntimeDescriptor: Sendable, Codable, Equatable {
    public let mode: SwiftWebClientRuntimeDescriptorMode
    public let hydrationIndex: BrowserHydrationIndex
    public let manifest: ClientBundleManifest?
    public let wasm: SwiftWebWasmClientRuntime?
    public let security: ClientSecurityDescriptor?
    public let actorBindings: [SwiftWebActorBindingRecord]

    public init(
        mode: SwiftWebClientRuntimeDescriptorMode,
        hydrationIndex: BrowserHydrationIndex,
        manifest: ClientBundleManifest? = nil,
        wasm: SwiftWebWasmClientRuntime? = nil,
        security: ClientSecurityDescriptor? = nil,
        actorBindings: [SwiftWebActorBindingRecord] = []
    ) {
        self.mode = mode
        self.hydrationIndex = hydrationIndex
        self.manifest = manifest
        self.wasm = wasm
        self.security = security
        self.actorBindings = actorBindings
    }
}

public enum SwiftWebClientRuntimeDescriptorMode: String, Sendable, Codable, Equatable {
    case wasm
}
