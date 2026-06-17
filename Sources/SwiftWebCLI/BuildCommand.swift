import Foundation
import SwiftWeb
import SwiftWebDevelopment

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
        let resolvedSwiftSDK = resolvedSwiftSDKName
        let wasmToolchain = try resolvedWasmToolchain(swiftSDK: resolvedSwiftSDK)
        let buildPackageDirectory = buildsWasmRuntime
            ? generatedPackage.wasmPackageDirectory
            : generatedPackage.packageDirectory
        var arguments = buildsWasmRuntime ? [
            "build",
            "--package-path",
            buildPackageDirectory.path,
            "--product",
            productName,
        ] : [
            "swift",
            "build",
            "--package-path",
            buildPackageDirectory.path,
            "--product",
            productName,
        ]

        if let resolvedScratchDirectory = scratchDirectory ?? defaultScratchDirectory(from: generatedPackage) {
            arguments.append("--scratch-path")
            arguments.append(resolvedScratchDirectory.path)
        }
        if let resolvedSwiftSDK {
            arguments.append("--swift-sdk")
            arguments.append(resolvedSwiftSDK)
        }
        if let configuration {
            arguments.append("-c")
            arguments.append(configuration)
        }

        var environment = ProcessInfo.processInfo.environment
        if buildsWasmRuntime {
            environment["SWIFTWEB_WASM_BUILD"] = "1"
            environment["SWIFTWEB_CORE_ONLY"] = "1"
            if let wasmToolchain {
                environment = wasmToolchain.applying(to: environment)
            }
        }

        try runProcess(arguments: arguments, environment: environment, wasmToolchain: wasmToolchain)
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
        let child = buildsWasmRuntime ? "wasm" : "server"
        return generatedPackage.rootDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent(child, isDirectory: true)
            .standardizedFileURL
    }

    private var resolvedSwiftSDKName: String? {
        if buildsWasmRuntime {
            return swiftSDK
                ?? ProcessInfo.processInfo.environment["SWIFT_WEB_WASM_SDK"]
                ?? SwiftWebWasmToolchain.defaultSwiftSDKName
        }
        return swiftSDK
    }

    private func resolvedWasmToolchain(swiftSDK: String?) throws -> SwiftWebWasmToolchain? {
        guard buildsWasmRuntime else {
            return nil
        }
        return try SwiftWebWasmToolchain.resolve(
            sdkName: swiftSDK ?? SwiftWebWasmToolchain.defaultSwiftSDKName
        )
    }

    private func runProcess(
        arguments: [String],
        environment: [String: String],
        wasmToolchain: SwiftWebWasmToolchain?
    ) throws {
        let process = Process()
        process.executableURL = processExecutableURL(wasmToolchain: wasmToolchain)
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
                message: "build failed with status \(process.terminationStatus): \(commandDescription(arguments, executableURL: process.executableURL))",
                exitCode: 70
            )
        }
    }

    private func processExecutableURL(wasmToolchain: SwiftWebWasmToolchain?) -> URL {
        if let wasmToolchain {
            return wasmToolchain.swiftExecutableURL
        }
        if buildsWasmRuntime {
            return URL(fileURLWithPath: "/usr/bin/env")
        }
        return URL(fileURLWithPath: "/usr/bin/xcrun")
    }

    private func commandDescription(_ arguments: [String], executableURL: URL?) -> String {
        let launcher = executableURL?.path ?? (buildsWasmRuntime ? "env" : "xcrun")
        return ([launcher] + arguments).joined(separator: " ")
    }
}
