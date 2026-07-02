import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import Foundation
import SwiftHTML

public struct SwiftWebGeneratedPackage: Sendable {
    public let appPackageDirectory: URL
    public let rootDirectory: URL
    public let packageDirectory: URL
    public let devPackageDirectory: URL
    public let wasmPackageDirectory: URL
    public let swiftWebPackageDirectory: URL
    public let appProductName: String
    public let serverProductName: String
    public let developmentServerProductName: String
    public let devProductName: String
    public let wasmProductNames: [String]
    public let wasmRuntimes: [SwiftWebGeneratedWasmRuntime]

    public init(
        appPackageDirectory: URL,
        rootDirectory: URL? = nil,
        packageDirectory: URL,
        devPackageDirectory: URL? = nil,
        wasmPackageDirectory: URL? = nil,
        swiftWebPackageDirectory: URL,
        appProductName: String,
        serverProductName: String,
        developmentServerProductName: String? = nil,
        devProductName: String,
        wasmProductNames: [String],
        wasmRuntimes: [SwiftWebGeneratedWasmRuntime]
    ) {
        self.appPackageDirectory = appPackageDirectory
        self.rootDirectory = rootDirectory ?? packageDirectory
        self.packageDirectory = packageDirectory
        self.devPackageDirectory = devPackageDirectory ?? packageDirectory
        self.wasmPackageDirectory = wasmPackageDirectory ?? packageDirectory
        self.swiftWebPackageDirectory = swiftWebPackageDirectory
        self.appProductName = appProductName
        self.serverProductName = serverProductName
        self.developmentServerProductName = developmentServerProductName ?? "\(serverProductName)-dev"
        self.devProductName = devProductName
        self.wasmProductNames = wasmProductNames
        self.wasmRuntimes = wasmRuntimes
    }
}

public struct SwiftWebGeneratedWasmRuntime: Sendable, Equatable {
    public let packageDirectory: URL
    public let targetName: String
    public let productName: String
    public let componentTypeNames: [String]
    public let bundleID: ClientBundleID
    public let assetPath: String
    public let linkMode: SwiftWebGeneratedWasmRuntimeLinkMode

    public var componentTypeName: String {
        componentTypeNames.first ?? targetName
    }

    public init(
        packageDirectory: URL = URL(fileURLWithPath: "."),
        targetName: String,
        productName: String,
        componentTypeName: String,
        bundleID: ClientBundleID? = nil,
        assetPath: String,
        linkMode: SwiftWebGeneratedWasmRuntimeLinkMode = .standalone
    ) {
        self.init(
            packageDirectory: packageDirectory,
            targetName: targetName,
            productName: productName,
            componentTypeNames: [componentTypeName],
            bundleID: bundleID,
            assetPath: assetPath,
            linkMode: linkMode
        )
    }

    public init(
        packageDirectory: URL = URL(fileURLWithPath: "."),
        targetName: String,
        productName: String,
        componentTypeNames: [String],
        bundleID: ClientBundleID? = nil,
        assetPath: String,
        linkMode: SwiftWebGeneratedWasmRuntimeLinkMode = .standalone
    ) {
        self.packageDirectory = packageDirectory.standardizedFileURL
        self.targetName = targetName
        self.productName = productName
        self.componentTypeNames = componentTypeNames.sorted()
        self.bundleID = bundleID ?? ClientBundleID(productName)
        self.assetPath = assetPath
        self.linkMode = linkMode
    }
}
