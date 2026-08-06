import Foundation

struct LifecycleCommand {
    let operation: SwiftWebExecutionPlan.Operation
    let packageDirectory: URL
    let environment: String?
    let host: String?
    let port: Int?

    static func parse(
        _ parser: ArgumentParser,
        operation: SwiftWebExecutionPlan.Operation
    ) throws -> LifecycleCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var environment: String?
        var host: String?
        var port: Int?
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
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }
        return LifecycleCommand(
            operation: operation,
            packageDirectory: packageDirectory.standardizedFileURL,
            environment: environment,
            host: host,
            port: port
        )
    }

    func run() async throws {
        try await SwiftWebProjectLifecycle(
            packageDirectory: packageDirectory,
            environmentOverride: environment,
            hostOverride: host,
            portOverride: port
        ).run(operation)
    }
}
