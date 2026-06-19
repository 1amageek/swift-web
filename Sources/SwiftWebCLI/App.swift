import Foundation
import SwiftWebDevelopment

@main
struct SwiftWebCLI {
    static func main() async {
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
            FileHandle.standardError.write(Data((error.description + "\n").utf8))
            Foundation.exit(Int32(error.exitCode))
        } catch {
            FileHandle.standardError.write(Data(("error: \(error)\n").utf8))
            Foundation.exit(1)
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
            try NewCommand.parse(parser).run()
        case "build":
            try BuildCommand.parse(parser).run()
        case "clean":
            try CleanCommand.parse(parser).run()
        case "dev":
            try await DevCommand.parse(parser).run()
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
              swift-web new <AppName> [--output <directory>] [--force]
              swift-web build [--package-path <directory>] [--product <name>] [--wasm] [--swift-sdk <sdk>] [-c debug|release]
              swift-web clean [--package-path <directory>] [--storyboard] [--swiftpm] [--all]
              swift-web dev [--package-path <directory>] [--product <name>] [--host <host>] [--port <port>]
              swift-web storyboard [--package-path <directory>] [--output <directory>] [--host <host>] [--port <port>] [--no-run] [--force]

            Commands:
              new         Create a minimal SwiftWeb app skeleton.
              build       Build the generated server or WASM runtime package.
              clean       Remove SwiftWeb generated build artifacts. Pass --swiftpm to remove the package .build too.
              dev         Run a SwiftWeb app with rebuild, server restart, and dev browser updates on changes.
              storyboard  Generate and run a SwiftWebUI component style storyboard.
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
