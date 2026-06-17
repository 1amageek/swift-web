import Foundation
import SwiftHTML
import Vapor

public struct ClientWasmRuntimeConfiguration {
    private let runtime: SwiftWebWasmClientRuntime
    private let assets: () throws -> [ClientWasmRuntimeAsset]

    public init(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        fileURL: URL,
        additionalBundles: [ClientWasmBundleArtifact] = [],
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
                [ClientWasmRuntimeAsset(path: assetPath, fileURL: fileURL)]
                    + (try additionalBundles.map { bundle in
                    ClientWasmRuntimeAsset(path: bundle.assetPath, fileURL: try bundle.fileURL())
                    })
            )
        }
    }

    public init(
        id: String = "runtime",
        manifestPath: String = "/assets/swift-web-client.json",
        assetPath: String,
        artifact: SwiftPMWasmArtifactLocation,
        additionalBundles: [ClientWasmBundleArtifact] = [],
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
                [ClientWasmRuntimeAsset(path: assetPath, fileURL: try artifact.url())]
                    + (try additionalBundles.map { bundle in
                    ClientWasmRuntimeAsset(path: bundle.assetPath, fileURL: try bundle.fileURL())
                    })
            )
        }
    }

    func install(on application: Application) throws {
        application.swiftWebClientRuntime = .wasm(runtime)
        SwiftWebWasmRuntimeRoutes.registerHost(on: application)
        for asset in try assets() {
            SwiftWebWasmRuntimeRoutes.registerWasmAsset(
                on: application,
                path: asset.path,
                fileURL: asset.fileURL
            )
        }
    }

    private static func uniqueAssets(_ assets: [ClientWasmRuntimeAsset]) -> [ClientWasmRuntimeAsset] {
        var seenPaths = Set<String>()
        return assets.filter { asset in
            seenPaths.insert(asset.path).inserted
        }
    }
}

public struct ClientWasmBundleArtifact {
    public let id: String
    public let componentTypeNames: [String]
    public let assetPath: String
    private let resolveFileURL: () throws -> URL

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

private struct ClientWasmRuntimeAsset {
    let path: String
    let fileURL: URL
}
