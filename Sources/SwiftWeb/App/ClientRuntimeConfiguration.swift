import Foundation
import Vapor

public enum ClientRuntimeConfiguration {
    case disabled
    case wasm(ClientWasmRuntimeConfiguration)

    public static func wasm(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        fileURL: URL,
        additionalBundles: [ClientWasmBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) -> Self {
        .wasm(ClientWasmRuntimeConfiguration(
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
        additionalBundles: [ClientWasmBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) -> Self {
        .wasm(ClientWasmRuntimeConfiguration(
            id: id,
            manifestPath: manifestPath,
            assetPath: assetPath,
            artifact: artifact,
            additionalBundles: additionalBundles,
            metricsMode: metricsMode
        ))
    }

    func install(on application: Application) async throws {
        switch self {
        case .disabled:
            application.swiftWebClientRuntime = .disabled
        case .wasm(let configuration):
            try configuration.install(on: application)
        }
    }
}
