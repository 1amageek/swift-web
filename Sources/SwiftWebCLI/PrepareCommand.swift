import Foundation
import SwiftWebDevelopment

struct PrepareCommand {
    let packageDirectory: URL
    let product: String
    let printsSummary: Bool

    static func parse(_ parser: ArgumentParser) throws -> PrepareCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var product = "app-server"

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--product":
                product = try parser.requireValue(after: option)
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return PrepareCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            product: product,
            printsSummary: true
        )
    }

    func run() throws {
        let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: packageDirectory,
            serverProductName: product
        )
        .materialize()

        guard printsSummary else {
            return
        }

        print(
            """
            Prepared SwiftWeb generated packages:
              server: \(generatedPackage.packageDirectory.path)
              dev: \(generatedPackage.devPackageDirectory.path)
              wasm: \(generatedPackage.wasmPackageDirectory.path)
            """
        )
    }
}
