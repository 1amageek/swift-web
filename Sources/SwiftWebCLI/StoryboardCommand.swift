import Foundation
import SwiftWebStoryboard

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
        let configuration = StoryboardRunner.Configuration(
            packageDirectory: packageDirectory,
            storyboardDirectory: storyboardDirectory,
            scratchDirectory: scratchDirectory,
            host: host,
            port: port,
            runsServer: runsServer,
            force: force
        )

        do {
            try StoryboardRunner(configuration: configuration).run()
        } catch let error as StoryboardError {
            throw CLIError(message: error.description, exitCode: error.exitCode)
        }
    }
}
