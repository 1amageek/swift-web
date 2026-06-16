import SwiftHTML
import Vapor

public enum SwiftWebClientRuntime: Sendable, Equatable {
    case disabled
    case wasm(SwiftWebWasmClientRuntime)

    var capturesClientHandlerClosures: Bool {
        false
    }

    var emitsBrowserHydrationMarkers: Bool {
        switch self {
        case .disabled:
            false
        case .wasm:
            true
        }
    }
}

public enum SwiftWebWasmMetricsMode: String, Sendable, Codable, Equatable {
    case disabled
    case summary
    case detailed
}

public struct SwiftWebWasmClientRuntime: Sendable, Codable, Equatable {
    public let runtimeBundleID: ClientBundleID
    public let manifestPath: String
    public let runtimeAssetPath: String
    public let additionalBundles: [SwiftWebWasmClientBundle]
    public let hostScriptPath: String
    public let javaScriptKitRuntimePath: String
    public let importNamespace: String
    public let metricsMode: SwiftWebWasmMetricsMode

    public init(
        runtimeBundleID: ClientBundleID = ClientBundleID("runtime"),
        manifestPath: String,
        runtimeAssetPath: String,
        additionalBundles: [SwiftWebWasmClientBundle] = [],
        hostScriptPath: String = SwiftWebWasmRuntimeRoutes.versionedHostScriptPath,
        javaScriptKitRuntimePath: String = SwiftWebWasmRuntimeRoutes.versionedJavaScriptKitRuntimePath,
        importNamespace: String = "swiftweb",
        metricsMode: SwiftWebWasmMetricsMode = .summary
    ) {
        self.runtimeBundleID = runtimeBundleID
        self.manifestPath = manifestPath
        self.runtimeAssetPath = runtimeAssetPath
        self.additionalBundles = additionalBundles
        self.hostScriptPath = hostScriptPath
        self.javaScriptKitRuntimePath = javaScriptKitRuntimePath
        self.importNamespace = importNamespace
        self.metricsMode = metricsMode
    }
}

public struct SwiftWebWasmClientBundle: Sendable, Codable, Equatable {
    public let id: ClientBundleID
    public let componentTypeName: String
    public let assetPath: String

    public init(
        id: ClientBundleID,
        componentTypeName: String,
        assetPath: String
    ) {
        self.id = id
        self.componentTypeName = componentTypeName
        self.assetPath = assetPath
    }
}

private struct SwiftWebClientRuntimeStorageKey: StorageKey {
    typealias Value = SwiftWebClientRuntime
}

public extension Application {
    var swiftWebClientRuntime: SwiftWebClientRuntime {
        get {
            storage[SwiftWebClientRuntimeStorageKey.self] ?? .disabled
        }
        set {
            storage[SwiftWebClientRuntimeStorageKey.self] = newValue
        }
    }
}
