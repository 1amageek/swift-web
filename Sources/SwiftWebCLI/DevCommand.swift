import Foundation
import SwiftWeb

struct DevCommand {
    let packageDirectory: URL
    let scratchDirectory: URL?
    let product: String
    let host: String
    let port: Int

    static func parse(_ parser: ArgumentParser) throws -> DevCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var scratchDirectory: URL?
        var product = "app-server"
        var host = "127.0.0.1"
        var port = 3000

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--scratch-path":
                scratchDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--product":
                product = try parser.requireValue(after: option)
            case "--host":
                host = try parser.requireValue(after: option)
            case "--port":
                port = try parser.requireInt(after: option)
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return DevCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            scratchDirectory: scratchDirectory?.standardizedFileURL,
            product: product,
            host: host,
            port: port
        )
    }

    func run() throws {
        let configuration = SwiftWebDevRuntimeConfiguration(
            packageDirectory: packageDirectory,
            scratchDirectory: scratchDirectory,
            product: product,
            host: host,
            port: port
        )

        do {
            try SwiftWebDevRuntime(configuration: configuration).run()
        } catch let error as SwiftWebDevRuntimeError {
            throw CLIError(message: error.description, exitCode: error.exitCode)
        }
    }
}
