import Foundation
import SwiftWebDevelopment

struct SwiftWebProjectLifecycle: Sendable {
    let packageDirectory: URL
    let environmentOverride: String?
    let hostOverride: String?
    let portOverride: Int?
    let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

    func run(_ operation: SwiftWebExecutionPlan.Operation) async throws {
        let resolution = try await SwiftWebProjectResolver().resolve(
            packageDirectory: packageDirectory
        )
        switch operation {
        case .prepare:
            let names = try environmentNamesForPrepare(resolution)
            for name in names {
                try await execute(
                    Self.operations(for: operation),
                    environmentName: name,
                    resolution: resolution
                )
            }
        case .build:
            let name = try selectedEnvironment(
                override: environmentOverride,
                defaultName: resolution.manifest.defaults.build,
                operation: operation
            )
            try await execute(
                Self.operations(for: operation),
                environmentName: name,
                resolution: resolution
            )
        case .dev:
            let name = try selectedEnvironment(
                override: environmentOverride,
                defaultName: resolution.manifest.defaults.dev,
                operation: operation
            )
            try await execute(
                Self.operations(for: operation),
                environmentName: name,
                resolution: resolution
            )
        case .deploy:
            let name = try selectedEnvironment(
                override: environmentOverride,
                defaultName: resolution.manifest.defaults.deploy,
                operation: operation
            )
            try await execute(
                Self.operations(for: operation),
                environmentName: name,
                resolution: resolution
            )
        }
    }

    static func operations(
        for operation: SwiftWebExecutionPlan.Operation
    ) -> [SwiftWebExecutionPlan.Operation] {
        switch operation {
        case .prepare:
            return [.prepare]
        case .build:
            return [.prepare, .build]
        case .dev:
            // The development runtime builds and watches its development
            // server product. Building the production server first duplicates
            // the full dependency build without producing an artifact used by
            // the development process.
            return [.prepare, .dev]
        case .deploy:
            return [.prepare, .build, .deploy]
        }
    }

    private func execute(
        _ operations: [SwiftWebExecutionPlan.Operation],
        environmentName: String,
        resolution: SwiftWebProjectResolution
    ) async throws {
        let environment = try resolution.environment(named: environmentName)
        let materialized = try SwiftWebEnvironmentMaterializer().materialize(
            resolution: resolution,
            environment: environment
        )
        let context = SwiftWebLifecycleExecutor.Context(
            resolution: resolution,
            materializedEnvironment: materialized,
            hostOverride: hostOverride,
            portOverride: portOverride,
            wasmRuntimeProfile: wasmRuntimeProfile
        )
        for operation in operations {
            let plan = try SwiftWebExecutionPlan.make(
                operation: operation,
                environment: environment
            )
            try await SwiftWebLifecycleExecutor().execute(plan: plan, context: context)
            print("SwiftWeb \(operation.rawValue) completed for \(environmentName)")
        }
    }

    private func environmentNamesForPrepare(
        _ resolution: SwiftWebProjectResolution
    ) throws -> [String] {
        if let environmentOverride {
            guard resolution.manifest.environments[environmentOverride] != nil else {
                throw SwiftWebLifecycleError.environmentNotFound(environmentOverride)
            }
            return [environmentOverride]
        }
        return resolution.manifest.environments.keys.sorted()
    }

    private func selectedEnvironment(
        override: String?,
        defaultName: String?,
        operation: SwiftWebExecutionPlan.Operation
    ) throws -> String {
        if let override {
            return override
        }
        guard let defaultName else {
            throw SwiftWebLifecycleError.defaultEnvironmentNotConfigured(operation.rawValue)
        }
        return defaultName
    }
}
