import Foundation
import SwiftWebDevelopment

@main
struct SwiftWebCLI {
    static func main() async {
        installConsoleLoggingIfNeeded(arguments: CommandLine.arguments)
        do {
            try await CommandLineInterface(arguments: CommandLine.arguments).run()
        } catch let error as CLIError {
            FileHandle.standardError.write(Data((error.message + "\n").utf8))
            Foundation.exit(Int32(error.exitCode))
        } catch let error as SwiftWebStoryboardScaffoldError {
            FileHandle.standardError.write(Data((error.description + "\n").utf8))
            Foundation.exit(Int32(error.exitCode))
        } catch let error as SwiftWebGeneratedPackageMaterializerError {
            FileHandle.standardError.write(Data((error.description + "\n").utf8))
            Foundation.exit(66)
        } catch let error as SwiftWebDevRuntimeError {
            if !shouldSuppressRuntimeError(error, arguments: CommandLine.arguments) {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
            }
            Foundation.exit(Int32(error.exitCode))
        } catch let error as SwiftWebLifecycleError {
            FileHandle.standardError.write(Data((error.description + "\n").utf8))
            Foundation.exit(Int32(error.exitCode))
        } catch {
            FileHandle.standardError.write(Data(("error: \(error)\n").utf8))
            Foundation.exit(1)
        }
    }

    private static func installConsoleLoggingIfNeeded(arguments: [String]) {
        guard let command = arguments.dropFirst().first else {
            return
        }
        guard command == "dev" || command == "storyboard" else {
            return
        }
        SwiftWebDevConsoleLogging.bootstrap()
    }

    private static func shouldSuppressRuntimeError(
        _ error: SwiftWebDevRuntimeError,
        arguments: [String]
    ) -> Bool {
        guard ProcessInfo.processInfo.environment["SWIFT_WEB_LOG_STYLE"] != "plain" else {
            return false
        }
        guard let command = arguments.dropFirst().first, command == "dev" || command == "storyboard" else {
            return false
        }
        switch error {
        case .portInUse:
            return true
        case .packageManifestNotFound, .processFailed, .executableNotFound, .hostReadinessTimeout,
             .workerPortAllocationFailed, .workerReadinessTimeout, .hostSwiftToolchainNotFound,
             .wasmToolchainNotFound, .unsupportedWasmSDK, .initialWasmBuildFailed,
             .workerBuildFailed, .buildTimedOut, .clientRuntimeTransactionFailed,
             .workerExitedDuringStartup, .artifactSnapshotFailed,
             .signalHandlerInstallationFailed, .processGroupIsolationFailed,
             .childProcessLifetimeMonitorLaunchFailed, .processTreeTerminationTimedOut,
             .processGroupTerminationTimedOut:
            return false
        }
    }
}

struct CommandLineInterface {
    let arguments: [String]

    func run() async throws {
        var parser = ArgumentParser(arguments: Array(arguments.dropFirst()))
        guard let command = parser.next() else {
            printUsage()
            return
        }

        switch command {
        case "new":
            try await NewCommand.parse(parser).run()
        case "prepare":
            try await LifecycleCommand.parse(parser, operation: .prepare).run()
        case "xcode":
            try XcodeCommand.parse(parser).run()
        case "build":
            try await LifecycleCommand.parse(parser, operation: .build).run()
        case "clean":
            try CleanCommand.parse(parser).run()
        case "dev":
            try await LifecycleCommand.parse(parser, operation: .dev).run()
        case "deploy":
            try await LifecycleCommand.parse(parser, operation: .deploy).run()
        case "storyboard":
            try await StoryboardCommand.parse(parser).run()
        case "help", "--help", "-h":
            printUsage()
        default:
            throw CLIError(message: "unknown command: \(command)", exitCode: 64)
        }
    }

    private func printUsage() {
        print(
            """
            Usage:
              sweb new <AppName> [--output <directory>] [--force] [--ai] [--adapter <owner/repository>]
              sweb prepare [--package-path <directory>] [--environment <name>] [--runtime standard|embedded]
              sweb xcode [--package-path <directory>] [--product <name>] [--no-open]
              sweb build [--package-path <directory>] [--environment <name>] [--runtime standard|embedded]
              sweb clean [--package-path <directory>] [--storyboard] [--swiftpm] [--all]
              sweb dev [--package-path <directory>] [--environment <name>] [--host <host>] [--port <port>]
              sweb deploy [--package-path <directory>] [--environment <name>] [--runtime standard|embedded]
              sweb storyboard [--package-path <directory>] [--output <directory>] [--host <host>] [--port <port>] [--no-run] [--force] [--production] [--runtime standard|embedded] [--swift-sdk <sdk>] [-c debug|release]

            Commands:
              new         Create a SwiftWeb app skeleton. Pass --ai for a chat-first template, and --adapter to add an adapter package.
              prepare     Resolve and materialize every configured application environment.
              xcode       Materialize generated packages and open the dev package in Xcode.
              build       Build the selected environment without changing remote state.
              clean       Remove SwiftWeb generated build artifacts. Pass --swiftpm to remove the package .build too.
              dev         Run a SwiftWeb app with rebuild, server restart, and dev browser updates on changes.
              deploy      Verify and deploy the selected environment.
              storyboard  Generate and run a SwiftWebUI component style storyboard.

            Package commands default to the current directory. Run them from the directory
            that contains Package.swift, or pass --package-path to target another package.
            """
        )
    }
}

struct ArgumentParser {
    private var arguments: [String]
    private var index: Int

    init(arguments: [String]) {
        self.arguments = arguments
        self.index = 0
    }

    mutating func next() -> String? {
        guard index < arguments.count else {
            return nil
        }
        let value = arguments[index]
        index += 1
        return value
    }

    mutating func requireValue(after option: String) throws -> String {
        guard let value = next(), !value.hasPrefix("--") else {
            throw CLIError(message: "missing value for \(option)", exitCode: 64)
        }
        return value
    }

    mutating func requireInt(after option: String) throws -> Int {
        let value = try requireValue(after: option)
        guard let integer = Int(value) else {
            throw CLIError(message: "invalid integer for \(option): \(value)", exitCode: 64)
        }
        return integer
    }

    mutating func requireDouble(after option: String) throws -> Double {
        let value = try requireValue(after: option)
        guard let double = Double(value) else {
            throw CLIError(message: "invalid number for \(option): \(value)", exitCode: 64)
        }
        return double
    }
}

struct CLIError: Error {
    let message: String
    let exitCode: Int
}
