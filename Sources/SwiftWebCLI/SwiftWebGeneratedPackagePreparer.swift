import Foundation
import SwiftWebDevelopment

struct SwiftWebGeneratedPackagePreparer {
    let packageDirectory: URL
    let product: String
    let printsSummary: Bool

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
