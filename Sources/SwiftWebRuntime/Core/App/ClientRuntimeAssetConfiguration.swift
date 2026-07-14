#if !hasFeature(Embedded)
// Native-host client-wasm asset plumbing; the embedded profile
// serves client bundles as static assets outside the Swift server.
import SwiftWebBrowserRuntime
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

public struct ClientRuntimeAssetConfiguration {
    private let runtime: SwiftWebWasmClientRuntime
    private let assets: @Sendable () throws -> [ClientRuntimeAsset]

    public init(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        fileURL: URL,
        additionalBundles: [ClientRuntimeBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) {
        let additionalRuntimeBundles = additionalBundles.map { bundle in
            SwiftWebWasmClientBundle(
                id: ClientBundleID(bundle.id),
                componentTypeNames: bundle.componentTypeNames,
                assetPath: bundle.assetPath
            )
        }
        self.runtime = SwiftWebWasmClientRuntime(
            runtimeBundleID: ClientBundleID(id),
            manifestPath: manifestPath,
            runtimeAssetPath: assetPath,
            additionalBundles: additionalRuntimeBundles,
            metricsMode: metricsMode
        )
        self.assets = {
            Self.uniqueAssets(
                [ClientRuntimeAsset(path: assetPath, fileURL: { fileURL })]
                    + additionalBundles.map { bundle in
                    ClientRuntimeAsset(path: bundle.assetPath, fileURL: { try bundle.fileURL() })
                    }
            )
        }
    }

    public init(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        artifact: SwiftPMWasmArtifactLocation,
        additionalBundles: [ClientRuntimeBundleArtifact] = [],
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) {
        let additionalRuntimeBundles = additionalBundles.map { bundle in
            SwiftWebWasmClientBundle(
                id: ClientBundleID(bundle.id),
                componentTypeNames: bundle.componentTypeNames,
                assetPath: bundle.assetPath
            )
        }
        self.runtime = SwiftWebWasmClientRuntime(
            runtimeBundleID: ClientBundleID(id),
            manifestPath: manifestPath,
            runtimeAssetPath: assetPath,
            additionalBundles: additionalRuntimeBundles,
            metricsMode: metricsMode
        )
        self.assets = {
            Self.uniqueAssets(
                [ClientRuntimeAsset(path: assetPath, fileURL: { try artifact.url() })]
                    + additionalBundles.map { bundle in
                    ClientRuntimeAsset(path: bundle.assetPath, fileURL: { try bundle.fileURL() })
                    }
            )
        }
    }

    func install(on application: Application) throws {
        application.swiftWebClientRuntime = .wasm(runtime)
        SwiftWebWasmRuntimeRoutes.registerHost(on: application.routes)
        for asset in try assets() {
            SwiftWebWasmRuntimeRoutes.registerWasmAsset(
                on: application.routes,
                path: asset.path,
                fileURL: asset.fileURL
            )
        }
    }

    private static func uniqueAssets(_ assets: [ClientRuntimeAsset]) -> [ClientRuntimeAsset] {
        var seenPaths = Set<String>()
        return assets.filter { asset in
            seenPaths.insert(asset.path).inserted
        }
    }
}

public struct ClientRuntimeBundleArtifact: Sendable {
    public let id: String
    public let componentTypeNames: [String]
    public let assetPath: String
    private let resolveFileURL: @Sendable () throws -> URL

    public var componentTypeName: String {
        componentTypeNames.first ?? ""
    }

    public init(
        id: String,
        componentTypeName: String,
        assetPath: String,
        fileURL: URL
    ) {
        self.init(
            id: id,
            componentTypeNames: [componentTypeName],
            assetPath: assetPath,
            fileURL: fileURL
        )
    }

    public init(
        id: String,
        componentTypeNames: [String],
        assetPath: String,
        fileURL: URL
    ) {
        self.id = id
        self.componentTypeNames = componentTypeNames.sorted()
        self.assetPath = assetPath
        self.resolveFileURL = { fileURL }
    }

    public init(
        id: String,
        componentTypeName: String,
        assetPath: String,
        artifact: SwiftPMWasmArtifactLocation
    ) {
        self.init(
            id: id,
            componentTypeNames: [componentTypeName],
            assetPath: assetPath,
            artifact: artifact
        )
    }

    public init(
        id: String,
        componentTypeNames: [String],
        assetPath: String,
        artifact: SwiftPMWasmArtifactLocation
    ) {
        self.id = id
        self.componentTypeNames = componentTypeNames.sorted()
        self.assetPath = assetPath
        self.resolveFileURL = artifact.url
    }

    func fileURL() throws -> URL {
        try resolveFileURL()
    }
}

private struct ClientRuntimeAsset: Sendable {
    let path: String
    let fileURL: @Sendable () throws -> URL
}
#endif
