import Foundation
import SwiftWebDevelopment

struct StoryboardCommand {
    let lifecycle: LifecycleCommand

    static func parse(_ parser: ArgumentParser) throws -> StoryboardCommand {
        var remaining = parser
        var operation = SwiftWebExecutionPlan.Operation.dev
        if let first = remaining.next(), !first.hasPrefix("-") {
            guard let selected = SwiftWebExecutionPlan.Operation(rawValue: first),
                selected != .deploy
            else {
                throw CLIError(message: "expected storyboard prepare, build, or dev", exitCode: 64)
            }
            operation = selected
        } else {
            remaining = parser
        }
        return StoryboardCommand(lifecycle: try LifecycleCommand.parse(remaining, operation: operation))
    }

    func resolvedLifecycleCommand() throws -> LifecycleCommand {
        let manifestURL = lifecycle.packageDirectory.appendingPathComponent("sweb.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw SwiftWebLifecycleError.projectManifestNotFound(manifestURL)
        }
        let selection: Selection
        do {
            selection = try JSONDecoder().decode(Selection.self, from: Data(contentsOf: manifestURL))
        } catch {
            throw CLIError(message: "invalid storyboard configuration at \(manifestURL.path): \(error)", exitCode: 65)
        }
        guard selection.schemaVersion == 3 else {
            throw SwiftWebLifecycleError.unsupportedProjectSchema(selection.schemaVersion)
        }
        guard let path = selection.storyboard?.packagePath else {
            throw CLIError(message: "storyboard.packagePath is not configured in \(manifestURL.path)", exitCode: 66)
        }
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !NSString(string: path).isAbsolutePath, !path.contains("\0")
        else {
            throw CLIError(message: "storyboard.packagePath must be a nonempty relative directory path", exitCode: 65)
        }
        let target = lifecycle.packageDirectory.appendingPathComponent(path, isDirectory: true).standardizedFileURL
        for name in ["Package.swift", "sweb.json"] {
            let file = target.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
                !isDirectory.boolValue
            else {
                throw CLIError(message: "storyboard target is missing \(file.path)", exitCode: 66)
            }
        }
        return LifecycleCommand(
            operation: lifecycle.operation,
            packageDirectory: target,
            environment: lifecycle.environment,
            host: lifecycle.host,
            port: lifecycle.port,
            wasmRuntimeProfile: lifecycle.wasmRuntimeProfile
        )
    }

    func run() async throws {
        try await resolvedLifecycleCommand().run()
    }

    private struct Selection: Decodable {
        let schemaVersion: Int
        let storyboard: Target?

        struct Target: Decodable {
            let packagePath: String
        }
    }
}
