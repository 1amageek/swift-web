import Foundation
import SwiftWebDevelopment

struct XcodeCommand {
    let packageDirectory: URL
    let product: String
    let opensXcode: Bool

    static func parse(_ parser: ArgumentParser) throws -> XcodeCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var product = "app-server"
        var opensXcode = true

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--product":
                product = try parser.requireValue(after: option)
            case "--no-open":
                opensXcode = false
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return XcodeCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            product: product,
            opensXcode: opensXcode
        )
    }

    func run() throws {
        let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: packageDirectory,
            serverProductName: product
        )
        .materialize()

        let xcodePackageDirectory = generatedPackage.devPackageDirectory
        print(
            """
            Prepared SwiftWeb generated packages:
              server: \(generatedPackage.packageDirectory.path)
              dev: \(xcodePackageDirectory.path)
              wasm: \(generatedPackage.wasmPackageDirectory.path)
            """
        )

        guard opensXcode else {
            print("Xcode package: \(xcodePackageDirectory.path)")
            return
        }

        try openInXcode(xcodePackageDirectory)
        print("Opened Xcode package: \(xcodePackageDirectory.path)")
    }

    private func openInXcode(_ packageDirectory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Xcode", packageDirectory.path]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw CLIError(
                message: "failed to open Xcode: \(error)",
                exitCode: 70
            )
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError(
                message: "failed to open Xcode with status \(process.terminationStatus)",
                exitCode: 70
            )
        }
    }
}
