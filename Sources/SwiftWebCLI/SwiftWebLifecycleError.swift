import Foundation

enum SwiftWebLifecycleError: Error, CustomStringConvertible {
    case projectManifestNotFound(URL)
    case unsupportedProjectSchema(Int)
    case unsupportedAdapterSchema(adapter: String, schema: Int)
    case malformedComponentSelector(String)
    case environmentNotFound(String)
    case defaultEnvironmentNotConfigured(String)
    case adapterNotFound(String)
    case duplicateAdapter(String)
    case hostNotFound(adapter: String, host: String)
    case deploymentNotFound(adapter: String, deployment: String)
    case incompatibleArtifacts(host: [String], deployment: [String])
    case packageDependencyInspectionFailed(status: Int32, output: String)
    case invalidTemplatePath(String)
    case missingTemplate(URL)
    case unsafeTemplateEntry(URL)
    case duplicateTask(String)
    case missingTaskDependency(task: String, dependency: String)
    case cyclicTaskDependencies([String])
    case invalidTask(task: String, reason: String)
    case taskFailed(task: String, status: Int32)

    var exitCode: Int {
        switch self {
        case .projectManifestNotFound, .environmentNotFound, .defaultEnvironmentNotConfigured,
             .adapterNotFound, .hostNotFound, .deploymentNotFound:
            66
        case .unsupportedProjectSchema, .unsupportedAdapterSchema, .malformedComponentSelector,
             .duplicateAdapter, .incompatibleArtifacts, .invalidTemplatePath, .missingTemplate,
             .unsafeTemplateEntry, .duplicateTask, .missingTaskDependency,
             .cyclicTaskDependencies, .invalidTask:
            65
        case .packageDependencyInspectionFailed, .taskFailed:
            70
        }
    }

    var description: String {
        switch self {
        case .projectManifestNotFound(let url):
            "SwiftWeb project manifest not found: \(url.path)"
        case .unsupportedProjectSchema(let schema):
            "unsupported SwiftWeb project schema version: \(schema)"
        case .unsupportedAdapterSchema(let adapter, let schema):
            "unsupported adapter schema version \(schema): \(adapter)"
        case .malformedComponentSelector(let selector):
            "invalid SwiftWeb adapter component selector: \(selector)"
        case .environmentNotFound(let environment):
            "SwiftWeb environment not found: \(environment)"
        case .defaultEnvironmentNotConfigured(let operation):
            "SwiftWeb default environment is not configured for \(operation)"
        case .adapterNotFound(let adapter):
            "SwiftWeb adapter package not found in Package.swift dependencies: \(adapter)"
        case .duplicateAdapter(let adapter):
            "multiple SwiftWeb adapters declare the same id: \(adapter)"
        case .hostNotFound(let adapter, let host):
            "SwiftWeb host component not found: \(adapter)/\(host)"
        case .deploymentNotFound(let adapter, let deployment):
            "SwiftWeb deployment component not found: \(adapter)/\(deployment)"
        case .incompatibleArtifacts(let host, let deployment):
            "SwiftWeb host artifacts \(host) are incompatible with deployment inputs \(deployment)"
        case .packageDependencyInspectionFailed(let status, let output):
            "Swift package dependency inspection failed with status \(status): \(output)"
        case .invalidTemplatePath(let path):
            "SwiftWeb adapter template path is unsafe: \(path)"
        case .missingTemplate(let url):
            "SwiftWeb adapter template not found: \(url.path)"
        case .unsafeTemplateEntry(let url):
            "SwiftWeb adapter template contains an unsupported entry: \(url.path)"
        case .duplicateTask(let task):
            "SwiftWeb lifecycle task id is duplicated: \(task)"
        case .missingTaskDependency(let task, let dependency):
            "SwiftWeb lifecycle task \(task) depends on missing task \(dependency)"
        case .cyclicTaskDependencies(let tasks):
            "SwiftWeb lifecycle task graph contains a cycle: \(tasks.joined(separator: ", "))"
        case .invalidTask(let task, let reason):
            "SwiftWeb lifecycle task \(task) is invalid: \(reason)"
        case .taskFailed(let task, let status):
            "SwiftWeb lifecycle task \(task) failed with status \(status)"
        }
    }
}
