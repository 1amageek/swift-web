import Foundation
import SwiftWeb

struct BuildCommand {
    let packageDirectory: URL
    let scratchDirectory: URL?
    let product: String?
    let buildsWasmRuntime: Bool
    let swiftSDK: String?
    let configuration: String?

    static func parse(_ parser: ArgumentParser) throws -> BuildCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var scratchDirectory: URL?
        var product: String?
        var buildsWasmRuntime = false
        var swiftSDK: String?
        var configuration: String?

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--scratch-path":
                scratchDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--product":
                product = try parser.requireValue(after: option)
            case "--wasm":
                buildsWasmRuntime = true
            case "--swift-sdk":
                swiftSDK = try parser.requireValue(after: option)
            case "-c", "--configuration":
                configuration = try parser.requireValue(after: option)
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return BuildCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            scratchDirectory: scratchDirectory?.standardizedFileURL,
            product: product,
            buildsWasmRuntime: buildsWasmRuntime,
            swiftSDK: swiftSDK,
            configuration: configuration
        )
    }

    func run() throws {
        let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: packageDirectory,
            serverProductName: product ?? "app-server"
        )
        .materialize()
        let productName = try resolvedProductName(from: generatedPackage)
        var arguments = [
            "swift",
            "build",
            "--package-path",
            generatedPackage.packageDirectory.path,
            "--product",
            productName,
        ]

        if let resolvedScratchDirectory = scratchDirectory ?? defaultScratchDirectory(from: generatedPackage) {
            arguments.append("--scratch-path")
            arguments.append(resolvedScratchDirectory.path)
        }
        if let swiftSDK {
            arguments.append("--swift-sdk")
            arguments.append(swiftSDK)
        }
        if let configuration {
            arguments.append("-c")
            arguments.append(configuration)
        }

        var environment = ProcessInfo.processInfo.environment
        if buildsWasmRuntime {
            environment["SWIFTWEB_WASM_BUILD"] = "1"
            environment["SWIFTWEB_CORE_ONLY"] = "1"
        }

        try runProcess(arguments: arguments, environment: environment)
    }

    private func resolvedProductName(from generatedPackage: SwiftWebGeneratedPackage) throws -> String {
        if let product {
            return product
        }
        if buildsWasmRuntime {
            guard let wasmProduct = generatedPackage.wasmProductNames.first else {
                throw CLIError(message: "no generated WASM runtime product was found", exitCode: 66)
            }
            return wasmProduct
        }
        return generatedPackage.serverProductName
    }

    private func defaultScratchDirectory(from generatedPackage: SwiftWebGeneratedPackage) -> URL? {
        guard !buildsWasmRuntime else {
            return nil
        }
        return generatedPackage.packageDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("server", isDirectory: true)
            .standardizedFileURL
    }

    private func runProcess(arguments: [String], environment: [String: String]) throws {
        let process = Process()
        process.executableURL = buildsWasmRuntime
            ? URL(fileURLWithPath: "/usr/bin/env")
            : URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.currentDirectoryURL = packageDirectory
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError(
                message: "build failed with status \(process.terminationStatus): \(commandDescription(arguments))",
                exitCode: 70
            )
        }
    }

    private func commandDescription(_ arguments: [String]) -> String {
        let launcher = buildsWasmRuntime ? "env" : "xcrun"
        return ([launcher] + arguments).joined(separator: " ")
    }
}
