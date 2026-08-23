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
        if let invalidServiceTask = projectTasks.first(where: {
            $0.stage == .beforeService || $0.stage == .afterService
        }) {
            throw SwiftWebLifecycleError.invalidTask(
                task: invalidServiceTask.id,
                reason: "environment tasks cannot use service lifecycle stages"
            )
        }
        for service in environment.services {
            let applicationTasks = service.project.operations[operation.rawValue] ?? []
            let adapterTasks = service.component.operations[operation.rawValue] ?? []
            if let invalidKind = (applicationTasks + adapterTasks).first(where: {
                $0.kind != .command
            }) {
                throw SwiftWebLifecycleError.invalidTask(
                    task: invalidKind.id,
                    reason: "service lifecycle tasks support only command kind"
                )
            }
            if let invalidApplicationTask = applicationTasks
                .first(where: {
                    $0.stage != nil
                        && $0.stage != .beforeService
                        && $0.stage != .afterService
                })
            {
                throw SwiftWebLifecycleError.invalidTask(
                    task: invalidApplicationTask.id,
                    reason: "service tasks require beforeService or afterService stages"
                )
            }
            if let invalidAdapterTask = adapterTasks
                .first(where: { $0.stage != nil })
            {
                throw SwiftWebLifecycleError.invalidTask(
                    task: invalidAdapterTask.id,
                    reason: "service adapter tasks cannot declare application lifecycle stages"
                )
            }
        }
        let serviceTasks = environment.services.flatMap { service in
            let applicationTasks = service.project.operations[operation.rawValue] ?? []
            let beforeService = applicationTasks.filter { $0.stage == .beforeService }
            let afterService = applicationTasks.filter {
                $0.stage == .afterService || $0.stage == nil
            }
            return
                (beforeService
                + (service.component.operations[operation.rawValue] ?? [])
                + afterService)
                .map { $0.scoped(to: service.name) }
        }
        let beforeHost = projectTasks.filter { $0.stage == .beforeHost }
        let afterHost = projectTasks.filter { $0.stage == .afterHost }
        let beforeDeployment = projectTasks.filter { $0.stage == .beforeDeployment }
        let afterDeployment = projectTasks.filter {
            $0.stage == .afterDeployment || $0.stage == nil
        }
        let ordered =
            serviceTasks
            + beforeHost
            + (environment.host.operations[operation.rawValue] ?? [])
            + afterHost
            + beforeDeployment
            + (environment.deployment.operations[operation.rawValue] ?? [])
            + afterDeployment
        let topologicallyOrderedTasks = try topologicallySorted(ordered)
        try validateLifetimes(topologicallyOrderedTasks, operation: operation)
        let tasks =
            topologicallyOrderedTasks.filter { $0.lifetime == .finite }
            + topologicallyOrderedTasks.filter { $0.lifetime == .persistent }
        return SwiftWebExecutionPlan(
            operation: operation,
            tasks: tasks
        )
    }

    private static func validateLifetimes(
        _ tasks: [SwiftWebLifecycleTask],
        operation: Operation
    ) throws {
        let persistentTasks = tasks.filter { $0.lifetime == .persistent }
        guard persistentTasks.isEmpty || operation == .dev else {
            throw SwiftWebLifecycleError.invalidTask(
                task: persistentTasks[0].id,
                reason: "persistent tasks are supported only by the dev operation"
            )
        }
        let persistentTaskIDs = Set(persistentTasks.map(\.id))
        for task in tasks {
            guard persistentTaskIDs.isDisjoint(with: task.dependsOn) else {
                throw SwiftWebLifecycleError.invalidTask(
                    task: task.id,
                    reason: "tasks cannot wait for persistent task completion"
                )
            }
        }
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
            let readyIDs =
                remainingDependencies
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
            for id in Array(remainingDependencies.keys) {
                remainingDependencies[id]?.remove(nextID)
            }
        }
        return result
    }
}
