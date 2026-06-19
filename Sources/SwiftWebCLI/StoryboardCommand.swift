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

    func run() async throws {
        let configuration = SwiftWebStoryboardRuntimeConfiguration(
            packageDirectory: packageDirectory,
            storyboardDirectory: storyboardDirectory,
            scratchDirectory: scratchDirectory,
            host: host,
            port: port,
            runsServer: runsServer,
            force: force
        )
        let observer = SwiftWebStoryboardRuntimeObserver(
            didGenerate: { directory in
                print("SwiftWeb storyboard generated at \(directory.path)")
            },
            didSkipServer: { packageDirectory in
                print("Run: swift-web storyboard --package-path \(packageDirectory.path)")
            },
            willStartServer: { host, port in
                print("SwiftWeb storyboard starting at http://\(host):\(port)")
            }
        )
        try await SwiftWebStoryboardRuntime(configuration: configuration, observer: observer).run()
    }
}
