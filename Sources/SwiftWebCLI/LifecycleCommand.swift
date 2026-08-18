import Foundation
import SwiftWebDevelopment

struct LifecycleCommand {
    let operation: SwiftWebExecutionPlan.Operation
    let packageDirectory: URL
    let environment: String?
    let host: String?
    let port: Int?
    let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

    static func parse(
        _ parser: ArgumentParser,
        operation: SwiftWebExecutionPlan.Operation
    ) throws -> LifecycleCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var environment: String?
        var host: String?
        var port: Int?
        var wasmRuntimeProfile = SwiftWebWasmRuntimeProfile.defaultValue()
        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--environment":
                environment = try parser.requireValue(after: option)
            case "--host" where operation == .dev:
                host = try parser.requireValue(after: option)
            case "--port" where operation == .dev:
                port = try parser.requireInt(after: option)
            case "--runtime", "--wasm-runtime":
                let rawValue = try parser.requireValue(after: option)
                guard let profile = SwiftWebWasmRuntimeProfile(rawValue: rawValue) else {
                    throw CLIError(
                        message:
                            "unknown WASM runtime profile: \(rawValue). Expected standard or embedded.",
                        exitCode: 64
                    )
                }
                guard operation != .dev || profile == .standard else {
                    throw CLIError(
                        message:
                            "the embedded WASM runtime is not supported by the development server; use prepare, build, or deploy",
                        exitCode: 64
                    )
                }
                wasmRuntimeProfile = profile
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }
        return LifecycleCommand(
            operation: operation,
            packageDirectory: packageDirectory.standardizedFileURL,
            environment: environment,
            host: host,
            port: port,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
    }

    func run() async throws {
        try await SwiftWebProjectLifecycle(
            packageDirectory: packageDirectory,
            environmentOverride: environment,
            hostOverride: host,
            portOverride: port,
            wasmRuntimeProfile: wasmRuntimeProfile
        ).run(operation)
    }
}
