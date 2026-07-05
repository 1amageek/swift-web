import Foundation
import SwiftWebDevelopment

struct StoryboardCommand {
    let packageDirectory: URL
    let storyboardDirectory: URL?
    let scratchDirectory: URL?
    let host: String
    let port: Int
    let runsServer: Bool
    let force: Bool
    let mode: StoryboardCommandMode
    let configuration: String?
    let swiftSDK: String?
    let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

    static func parse(_ parser: ArgumentParser) throws -> StoryboardCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var storyboardDirectory: URL?
        var scratchDirectory: URL?
        var host = "127.0.0.1"
        var port = 3000
        var runsServer = true
        var force = false
        var mode = StoryboardCommandMode.development
        var configuration: String?
        var swiftSDK: String?
        var wasmRuntimeProfile = SwiftWebWasmRuntimeProfile.defaultValue()

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--output":
                storyboardDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--scratch-path":
                scratchDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--host":
                host = try parser.requireValue(after: option)
            case "--port":
                port = try parser.requireInt(after: option)
            case "--no-run":
                runsServer = false
            case "--force":
                force = true
            case "--production", "--compress":
                mode = .production
            case "--embedded":
                throw CLIError(
                    message:
                        "unsupported WASM runtime profile: embedded. SwiftWeb supports the standard WASM profile only.",
                    exitCode: 64
                )
            case "--runtime", "--wasm-runtime":
                let rawValue = try parser.requireValue(after: option)
                guard rawValue == SwiftWebWasmRuntimeProfile.standard.rawValue else {
                    throw CLIError(
                        message:
                            "unsupported WASM runtime profile: \(rawValue). SwiftWeb supports the standard WASM profile only.",
                        exitCode: 64
                    )
                }
                mode = .production
                wasmRuntimeProfile = .standard
            case "--swift-sdk":
                swiftSDK = try parser.requireValue(after: option)
            case "-c", "--configuration":
                configuration = try parser.requireValue(after: option)
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        if mode == .production, wasmRuntimeProfile != .standard {
            throw CLIError(
                message:
                    "unsupported WASM runtime profile: \(wasmRuntimeProfile.rawValue). SwiftWeb supports the standard WASM profile only.",
                exitCode: 64
            )
        }

        return StoryboardCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            storyboardDirectory: storyboardDirectory?.standardizedFileURL,
            scratchDirectory: scratchDirectory?.standardizedFileURL,
            host: host,
            port: port,
            runsServer: runsServer,
            force: force,
            mode: mode,
            configuration: configuration,
            swiftSDK: swiftSDK,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
    }

    func run() async throws {
        let resolvedPort = runsServer
            ? SwiftWebDevPortProbe.firstAvailablePort(host: host, startingAt: port)
            : port
        if runsServer, resolvedPort != port {
            FileHandle.standardError.write(Data("Port \(port) is in use; using \(resolvedPort).\n".utf8))
        }
        let resolvedStoryboardDirectory = storyboardDirectory
            ?? packageDirectory
                .appendingPathComponent(".swiftweb", isDirectory: true)
                .appendingPathComponent("storyboard", isDirectory: true)
                .standardizedFileURL
        let configuration = SwiftWebStoryboardRuntimeConfiguration(
            packageDirectory: packageDirectory,
            storyboardDirectory: resolvedStoryboardDirectory,
            scratchDirectory: scratchDirectory,
            host: host,
            port: resolvedPort,
            runsServer: mode == .development ? runsServer : false,
            force: force
        )
        let observer = SwiftWebStoryboardRuntimeObserver(
            didGenerate: { directory in
                print("SwiftWeb storyboard generated at \(directory.path)")
            },
            didSkipServer: { packageDirectory in
                if mode == .development {
                    print("Run: sweb storyboard --package-path \(packageDirectory.path)")
                }
            },
            willStartServer: { host, port in
                print("SwiftWeb storyboard starting at http://\(host):\(port)")
            }
        )
        try await SwiftWebStoryboardRuntime(configuration: configuration, observer: observer).run()
        guard mode == .production else {
            return
        }

        let productionServer = StoryboardProductionServer(
            packageDirectory: resolvedStoryboardDirectory,
            scratchDirectory: scratchDirectory,
            host: host,
            port: resolvedPort,
            runsServer: runsServer,
            configuration: self.configuration ?? "release",
            swiftSDK: swiftSDK,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
        try productionServer.run()
    }
}

enum StoryboardCommandMode {
    case development
    case production
}
