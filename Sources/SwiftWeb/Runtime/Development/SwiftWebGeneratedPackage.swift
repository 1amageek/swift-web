import Foundation

public struct SwiftWebGeneratedPackage: Sendable {
    public let appPackageDirectory: URL
    public let packageDirectory: URL
    public let swiftWebPackageDirectory: URL
    public let appProductName: String
    public let serverProductName: String
    public let devProductName: String
    public let wasmProductNames: [String]
    public let wasmRuntimes: [SwiftWebGeneratedWasmRuntime]
}

public struct SwiftWebGeneratedWasmRuntime: Sendable, Equatable {
    public let targetName: String
    public let productName: String
    public let componentTypeName: String
    public let assetPath: String

    public init(
        targetName: String,
        productName: String,
        componentTypeName: String,
        assetPath: String
    ) {
        self.targetName = targetName
        self.productName = productName
        self.componentTypeName = componentTypeName
        self.assetPath = assetPath
    }
}
