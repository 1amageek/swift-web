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

    static func parse(_ parser: ArgumentParser) throws -> StoryboardCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var storyboardDirectory: URL?
        var scratchDirectory: URL?
        var host = "127.0.0.1"
        var port = 3001
        var runsServer = true
        var force = false

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
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return StoryboardCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            storyboardDirectory: storyboardDirectory?.standardizedFileURL,
            scratchDirectory: scratchDirectory?.standardizedFileURL,
            host: host,
            port: port,
            runsServer: runsServer,
            force: force
        )
    }

    func run() throws {
        let swiftWebDirectory = try resolveSwiftWebPackageDirectory()
        let directory = storyboardDirectory
            ?? packageDirectory
                .appendingPathComponent(".swiftweb", isDirectory: true)
                .appendingPathComponent("storyboard", isDirectory: true)
                .standardizedFileURL
        let scaffold = StoryboardScaffold(
            projectDirectory: directory,
            swiftWebPackageDirectory: swiftWebDirectory
        )

        try scaffold.materialize(force: force)
        _ = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: directory
        )
        .materialize()

        print("SwiftWeb storyboard generated at \(directory.path)")
        if !runsServer {
            print("Run: swift-web storyboard --package-path \(packageDirectory.path)")
            return
        }

        print("SwiftWeb storyboard starting at http://\(host):\(port)")
        let configuration = SwiftWebDevRuntimeConfiguration(
            packageDirectory: directory,
            scratchDirectory: scratchDirectory,
            product: "app-server",
            host: host,
            port: port
        )

        do {
            try SwiftWebDevRuntime(configuration: configuration).run()
        } catch let error as SwiftWebDevRuntimeError {
            throw CLIError(message: error.description, exitCode: error.exitCode)
        }
    }

    private func resolveSwiftWebPackageDirectory() throws -> URL {
        let packageName = try Self.packageName(in: packageDirectory)
        if packageName == "swift-web" {
            return packageDirectory
        }

        for root in try Self.localPackageRoots(for: packageDirectory) {
            if try Self.packageName(in: root) == "swift-web" {
                return root
            }
        }

        throw CLIError(
            message: "local dependency swift-web was not found in \(packageDirectory.path)",
            exitCode: 66
        )
    }

    private static func packageName(in packageDirectory: URL) throws -> String {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            throw CLIError(message: "Package.swift was not found in \(packageDirectory.path)", exitCode: 66)
        }

        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"Package\s*\(\s*name\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        guard let match = regex.firstMatch(in: manifest, range: range),
              match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: manifest)
        else {
            throw CLIError(message: "package name was not found in \(packageFile.path)", exitCode: 66)
        }

        return String(manifest[nameRange])
    }

    private static func localPackageRoots(for packageDirectory: URL) throws -> [URL] {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"\.package\s*\(\s*path\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        let matches = regex.matches(in: manifest, range: range)
        var roots: [URL] = []
        var seenPaths = Set<String>()

        for match in matches {
            guard match.numberOfRanges > 1,
                  let pathRange = Range(match.range(at: 1), in: manifest)
            else {
                continue
            }

            let rawPath = String(manifest[pathRange])
            let root = rawPath.hasPrefix("/")
                ? URL(fileURLWithPath: rawPath).standardizedFileURL
                : packageDirectory.appendingPathComponent(rawPath, isDirectory: true).standardizedFileURL
            let rootPackageFile = root.appendingPathComponent("Package.swift")
            guard FileManager.default.fileExists(atPath: rootPackageFile.path) else {
                continue
            }

            if seenPaths.insert(root.path).inserted {
                roots.append(root)
            }
        }

        return roots
    }
}
