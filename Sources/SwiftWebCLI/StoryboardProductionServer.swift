import Foundation
import SwiftWebDevelopment

struct StoryboardProductionServer {
    let packageDirectory: URL
    let scratchDirectory: URL?
    let host: String
    let port: Int
    let runsServer: Bool
    let configuration: String
    let swiftSDK: String?
    let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

    func run() throws {
        let scratchRoot = resolvedScratchRoot
        let wasmScratchDirectory = scratchRoot
            .appendingPathComponent("wasm", isDirectory: true)
            .standardizedFileURL
        let serverScratchDirectory = scratchRoot
            .appendingPathComponent("server", isDirectory: true)
            .standardizedFileURL

        print(
            """
            SwiftWeb storyboard production build:
              runtime: \(wasmRuntimeProfile.rawValue)
              configuration: \(configuration)
              compression: gzip, brotli
            """
        )

        try BuildCommand(
            packageDirectory: packageDirectory,
            scratchDirectory: wasmScratchDirectory,
            product: nil,
            buildsWasmRuntime: true,
            swiftSDK: swiftSDK,
            configuration: configuration,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
        .run()

        try BuildCommand(
            packageDirectory: packageDirectory,
            scratchDirectory: serverScratchDirectory,
            product: nil,
            buildsWasmRuntime: false,
            swiftSDK: nil,
            configuration: configuration,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
        .run()

        guard runsServer else {
            print("SwiftWeb storyboard production build completed at \(packageDirectory.path)")
            return
        }

        let executableURL = try serverExecutableURL(scratchDirectory: serverScratchDirectory)
        print("SwiftWeb storyboard production starting at http://\(host):\(port)")
        try runServer(executableURL: executableURL, wasmScratchDirectory: wasmScratchDirectory)
    }

    private var resolvedScratchRoot: URL {
        if let scratchDirectory {
            return scratchDirectory.standardizedFileURL
        }
        // Keep the production scratch OUTSIDE `.swiftweb/generated`: the package
        // materializer wipes `generated/.build` on every `materialize()` call, so
        // a scratch nested there gets deleted by the server build's
        // re-materialize, taking the freshly built WASM runtime with it before it
        // can be served (the `/assets/*.wasm` 404). A sibling of `generated`
        // survives both materialize passes.
        return packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("production", isDirectory: true)
            .standardizedFileURL
    }

    private var serverPackageDirectory: URL {
        packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("generated", isDirectory: true)
            .appendingPathComponent("server", isDirectory: true)
            .standardizedFileURL
    }

    private func serverExecutableURL(scratchDirectory: URL) throws -> URL {
        let arguments = [
            "build",
            "--package-path",
            serverPackageDirectory.path,
            "--product",
            "app-server",
            "--scratch-path",
            scratchDirectory.path,
            "-c",
            configuration,
            "--show-bin-path",
        ]
        let binPath = try capturedProcessOutput(arguments: arguments)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !binPath.isEmpty else {
            throw CLIError(message: "swift build --show-bin-path returned an empty path", exitCode: 70)
        }
        let executableURL = URL(fileURLWithPath: binPath, isDirectory: true)
            .appendingPathComponent("app-server")
            .standardizedFileURL
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw CLIError(
                message: "production storyboard executable was not found at \(executableURL.path)",
                exitCode: 66
            )
        }
        return executableURL
    }

    private func capturedProcessOutput(arguments: [String]) throws -> String {
        let invocation = SwiftBuildInvocation.host()
        let launchedArguments = invocation.arguments(for: arguments)
        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = launchedArguments
        process.currentDirectoryURL = packageDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let stderr = String(decoding: errorOutput, as: UTF8.self)
            if !stderr.isEmpty {
                FileHandle.standardError.write(Data(stderr.utf8))
            }
            throw CLIError(
                message: "process failed with status \(process.terminationStatus): \(([process.executableURL?.path ?? "env"] + launchedArguments).joined(separator: " "))",
                exitCode: 70
            )
        }
        return String(decoding: output, as: UTF8.self)
    }

    private func runServer(executableURL: URL, wasmScratchDirectory: URL) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "serve",
            "--hostname",
            host,
            "--port",
            String(port),
        ]
        process.currentDirectoryURL = packageDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["SWIFTWEB_WASM_SCRATCH_PATH"] = wasmScratchDirectory.path
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError(
                message: "production storyboard server exited with status \(process.terminationStatus)",
                exitCode: 70
            )
        }
    }
}
