import Foundation
import SwiftWebCore
import SwiftWebDevelopment

struct SwiftWebLifecycleExecutor: Sendable {
    struct Context: Sendable {
        let resolution: SwiftWebProjectResolution
        let materializedEnvironment: SwiftWebEnvironmentMaterializer.MaterializedEnvironment
        let hostOverride: String?
        let portOverride: Int?
        let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile
    }

    func execute(plan: SwiftWebExecutionPlan, context: Context) async throws {
        let finiteTasks = plan.tasks.filter { $0.lifetime == .finite }
        let persistentTasks = plan.tasks.filter { $0.lifetime == .persistent }
        for task in finiteTasks {
            try await execute(task, context: context)
        }
        guard !persistentTasks.isEmpty else {
            return
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in persistentTasks {
                group.addTask {
                    try await self.execute(task, context: context)
                    throw SwiftWebLifecycleError.persistentTaskExited(task.id)
                }
            }
            do {
                _ = try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func execute(
        _ task: SwiftWebLifecycleTask,
        context: Context
    ) async throws {
        if try isFresh(task, context: context) {
            print("Skipping \(task.id) (outputs are current)")
            return
        }
        print("→ \(task.id)")
        switch task.kind {
        case .command:
            try await runCommand(task, context: context)
        case .prepareApplication:
            try SwiftWebGeneratedPackagePreparer(
                packageDirectory: context.resolution.packageDirectory,
                product: "app-server",
                printsSummary: false,
                wasmRuntimeProfile: context.wasmRuntimeProfile
            ).run()
        case .buildServer:
            try await SwiftWebGeneratedPackageBuilder(
                packageDirectory: context.resolution.packageDirectory,
                scratchDirectory: nil,
                product: nil,
                buildsWasmRuntime: false,
                swiftSDK: nil,
                configuration: nil,
                wasmRuntimeProfile: context.wasmRuntimeProfile
            ).run()
        case .buildBrowserRuntime:
            try await SwiftWebGeneratedPackageBuilder(
                packageDirectory: context.resolution.packageDirectory,
                scratchDirectory: nil,
                product: nil,
                buildsWasmRuntime: true,
                swiftSDK: nil,
                configuration: nil,
                wasmRuntimeProfile: context.wasmRuntimeProfile
            ).run()
        case .runDevelopmentServer:
            try await runDevelopmentServer(context: context)
        }
    }

    private func runDevelopmentServer(context: Context) async throws {
        let configuration = SwiftWebDevRuntimeConfiguration(
            packageDirectory: context.resolution.packageDirectory,
            product: "app-server",
            host: context.hostOverride ?? "127.0.0.1",
            port: context.portOverride ?? 3000
        )
        try await SwiftWebDevRuntime(configuration: configuration).run()
    }

    private func runCommand(
        _ task: SwiftWebLifecycleTask,
        context: Context
    ) async throws {
        guard let executable = task.executable, !executable.isEmpty else {
            throw SwiftWebLifecycleError.invalidTask(
                task: task.id,
                reason: "command tasks require executable"
            )
        }
        let renderedExecutable = render(executable, context: context)
        let process = Process()
        if renderedExecutable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: renderedExecutable)
            process.arguments = task.arguments.map { render($0, context: context) }
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments =
                [renderedExecutable]
                + task.arguments.map { render($0, context: context) }
        }
        process.currentDirectoryURL = try workingDirectory(task, context: context)
        var environment = ProcessInfo.processInfo.environment
        environment["SWIFTWEB_WASM_RUNTIME_PROFILE"] = context.wasmRuntimeProfile.rawValue
        for (key, value) in task.environment {
            environment[key] = render(value, context: context)
        }
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        let status = try await SwiftWebLifecycleCommandRunner().run(process)
        guard status == 0 else {
            throw SwiftWebLifecycleError.taskFailed(
                task: task.id,
                status: status
            )
        }
    }

    private func workingDirectory(
        _ task: SwiftWebLifecycleTask,
        context: Context
    ) throws -> URL {
        guard let path = task.workingDirectory else {
            return context.materializedEnvironment.workspaceDirectory
        }
        let rendered = render(path, context: context)
        if rendered.hasPrefix("/") {
            return URL(fileURLWithPath: rendered, isDirectory: true).standardizedFileURL
        }
        guard !rendered.split(separator: "/").contains("..") else {
            throw SwiftWebLifecycleError.invalidTask(
                task: task.id,
                reason: "workingDirectory escapes the generated workspace"
            )
        }
        return context.materializedEnvironment.workspaceDirectory
            .appendingPathComponent(rendered, isDirectory: true)
            .standardizedFileURL
    }

    private func isFresh(
        _ task: SwiftWebLifecycleTask,
        context: Context
    ) throws -> Bool {
        guard !task.outputs.isEmpty else {
            return false
        }
        let outputs = try task.outputs.map { try artifactURL($0, task: task, context: context) }
        guard outputs.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            return false
        }
        guard !task.inputs.isEmpty else {
            return true
        }
        let inputs = try task.inputs.map { try artifactURL($0, task: task, context: context) }
        guard inputs.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            return false
        }
        let newestInput = try inputs.compactMap {
            try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }.max()
        let oldestOutput = try outputs.compactMap {
            try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }.min()
        guard let newestInput, let oldestOutput else {
            return false
        }
        return oldestOutput >= newestInput
    }

    private func artifactURL(
        _ path: String,
        task: SwiftWebLifecycleTask,
        context: Context
    ) throws -> URL {
        let rendered = render(path, context: context)
        if rendered.hasPrefix("/") {
            return URL(fileURLWithPath: rendered).standardizedFileURL
        }
        guard !rendered.split(separator: "/").contains("..") else {
            throw SwiftWebLifecycleError.invalidTask(
                task: task.id,
                reason: "artifact path escapes the generated workspace"
            )
        }
        return context.materializedEnvironment.workspaceDirectory
            .appendingPathComponent(rendered)
            .standardizedFileURL
    }

    private func render(_ value: String, context: Context) -> String {
        let rendered = value.replacingOccurrences(
            of: "{{swiftweb.wasmRuntimeProfile}}",
            with: context.wasmRuntimeProfile.rawValue
        )
        return context.materializedEnvironment.substitutions.reduce(rendered) { partial, entry in
            partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
    }
}
