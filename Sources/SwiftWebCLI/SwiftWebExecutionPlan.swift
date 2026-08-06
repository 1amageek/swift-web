import Foundation

struct SwiftWebExecutionPlan: Sendable {
    enum Operation: String, Sendable {
        case prepare
        case build
        case dev
        case deploy
    }

    let operation: Operation
    let tasks: [SwiftWebLifecycleTask]

    static func make(
        operation: Operation,
        environment: SwiftWebProjectResolution.Environment
    ) throws -> SwiftWebExecutionPlan {
        let projectTasks = environment.project.operations[operation.rawValue] ?? []
        let beforeHost = projectTasks.filter { $0.stage == .beforeHost }
        let afterHost = projectTasks.filter { $0.stage == .afterHost }
        let beforeDeployment = projectTasks.filter { $0.stage == .beforeDeployment }
        let afterDeployment = projectTasks.filter {
            $0.stage == .afterDeployment || $0.stage == nil
        }
        let ordered = beforeHost
            + (environment.host.operations[operation.rawValue] ?? [])
            + afterHost
            + beforeDeployment
            + (environment.deployment.operations[operation.rawValue] ?? [])
            + afterDeployment
        return SwiftWebExecutionPlan(
            operation: operation,
            tasks: try topologicallySorted(ordered)
        )
    }

    private static func topologicallySorted(
        _ tasks: [SwiftWebLifecycleTask]
    ) throws -> [SwiftWebLifecycleTask] {
        var taskByID: [String: SwiftWebLifecycleTask] = [:]
        var sourceIndex: [String: Int] = [:]
        for (index, task) in tasks.enumerated() {
            guard taskByID[task.id] == nil else {
                throw SwiftWebLifecycleError.duplicateTask(task.id)
            }
            taskByID[task.id] = task
            sourceIndex[task.id] = index
        }
        for task in tasks {
            for dependency in task.dependsOn where taskByID[dependency] == nil {
                throw SwiftWebLifecycleError.missingTaskDependency(
                    task: task.id,
                    dependency: dependency
                )
            }
        }

        var remainingDependencies = Dictionary(
            uniqueKeysWithValues: tasks.map { ($0.id, Set($0.dependsOn)) }
        )
        var result: [SwiftWebLifecycleTask] = []
        while result.count < tasks.count {
            let readyIDs = remainingDependencies
                .filter { $0.value.isEmpty }
                .map(\.key)
                .sorted { (sourceIndex[$0] ?? 0) < (sourceIndex[$1] ?? 0) }
            guard let nextID = readyIDs.first, let next = taskByID[nextID] else {
                throw SwiftWebLifecycleError.cyclicTaskDependencies(
                    remainingDependencies.keys.sorted()
                )
            }
            result.append(next)
            remainingDependencies.removeValue(forKey: nextID)
            for id in remainingDependencies.keys {
                remainingDependencies[id]?.remove(nextID)
            }
        }
        return result
    }
}
