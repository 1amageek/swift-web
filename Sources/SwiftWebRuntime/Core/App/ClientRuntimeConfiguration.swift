#if !hasFeature(Embedded)
import SwiftWebBrowserRuntime
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

public enum ClientRuntimeConfiguration {
    case disabled
    case wasm(ClientRuntimeAssetConfiguration)

    public static func wasm(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        fileURL: URL,
        additionalBundles: [ClientRuntimeBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) -> Self {
        .wasm(ClientRuntimeAssetConfiguration(
            id: id,
            manifestPath: manifestPath,
            assetPath: assetPath,
            fileURL: fileURL,
            additionalBundles: additionalBundles,
            metricsMode: metricsMode
        ))
    }

    public static func wasm(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        artifact: SwiftPMWasmArtifactLocation,
        additionalBundles: [ClientRuntimeBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) -> Self {
        .wasm(ClientRuntimeAssetConfiguration(
            id: id,
            manifestPath: manifestPath,
            assetPath: assetPath,
            artifact: artifact,
            additionalBundles: additionalBundles,
            metricsMode: metricsMode
        ))
    }

    public func install(on application: Application) async throws {
        switch self {
        case .disabled:
            application.swiftWebClientRuntime = .disabled
        case .wasm(let configuration):
            try configuration.install(on: application)
        }
    }
}
#else
/// Embedded profile: the client runtime is always disabled (client bundles
/// are served as static assets and built with the full toolchain).
public enum ClientRuntimeConfiguration {
    case disabled
}
#endif
