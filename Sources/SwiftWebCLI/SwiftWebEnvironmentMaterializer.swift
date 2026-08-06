import Foundation

struct SwiftWebEnvironmentMaterializer: Sendable {
    struct MaterializedEnvironment: Sendable {
        let environment: SwiftWebProjectResolution.Environment
        let rootDirectory: URL
        let workspaceDirectory: URL
        let substitutions: [String: String]
    }

    private struct MaterializationRecord: Codable {
        let schemaVersion: Int
        let managedPaths: [String]
    }

    private struct PlanLock: Codable {
        struct Component: Codable {
            let adapter: String
            let name: String
            let packageIdentity: String
            let version: String
            let path: String
        }

        let schemaVersion: Int
        let environment: String
        let applicationProduct: String
        let applicationType: String
        let host: Component
        let deployment: Component
    }

    func materialize(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment
    ) throws -> MaterializedEnvironment {
        let rootDirectory = resolution.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("generated", isDirectory: true)
            .appendingPathComponent("environments", isDirectory: true)
            .appendingPathComponent(environment.name, isDirectory: true)
        let workspaceDirectory = rootDirectory.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workspaceDirectory,
            withIntermediateDirectories: true
        )

        let substitutions = substitutions(
            resolution: resolution,
            environment: environment,
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory
        )
        var managedPaths = Set<String>()
        for template in environment.host.templates {
            try copyTemplate(
                template,
                adapterDirectory: environment.hostAdapter.directory,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                managedPaths: &managedPaths
            )
        }
        for template in environment.deployment.templates {
            try copyTemplate(
                template,
                adapterDirectory: environment.deploymentAdapter.directory,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                managedPaths: &managedPaths
            )
        }
        for overlay in environment.project.overlays {
            let source = try safeRelativeURL(
                overlay.source,
                under: resolution.packageDirectory
            )
            let destination = try safeRelativeURL(
                overlay.destination,
                under: workspaceDirectory
            )
            try copyDirectory(
                from: source,
                to: destination,
                sourceRoot: source,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                excludedPaths: overlay.excluding,
                managedPaths: &managedPaths
            )
        }

        try removeStaleManagedPaths(
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory,
            nextManagedPaths: managedPaths
        )
        try writeMaterializationRecord(managedPaths, rootDirectory: rootDirectory)
        try writePlanLock(
            resolution: resolution,
            environment: environment,
            rootDirectory: rootDirectory
        )
        return MaterializedEnvironment(
            environment: environment,
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory,
            substitutions: substitutions
        )
    }

    private func substitutions(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment,
        rootDirectory: URL,
        workspaceDirectory: URL
    ) -> [String: String] {
        let application = resolution.manifest.application
        var values: [String: String] = [
            "project.root": resolution.packageDirectory.path,
            "generated.root": rootDirectory.path,
            "workspace.root": workspaceDirectory.path,
            "environment.name": environment.name,
            "application.packageIdentity": resolution.package.identity,
            "application.product": application.product,
            "application.module": application.module ?? application.product,
            "application.type": application.type,
            "application.kebabName": Self.kebabCase(application.product),
        ]
        values["adapter.\(environment.hostAdapter.manifest.id).root"] =
            environment.hostAdapter.directory.path
        values["adapter.\(environment.hostAdapter.manifest.id).swiftPackageRequirement"] =
            swiftPackageRequirement(environment.hostAdapter.package)
        values["adapter.\(environment.deploymentAdapter.manifest.id).root"] =
            environment.deploymentAdapter.directory.path
        values["adapter.\(environment.deploymentAdapter.manifest.id).swiftPackageRequirement"] =
            swiftPackageRequirement(environment.deploymentAdapter.package)
        values.merge(environment.host.variables) { _, host in host }
        values.merge(environment.deployment.variables) { _, deployment in deployment }
        return values
    }

    private func swiftPackageRequirement(
        _ package: SwiftPackageDependencyGraph.Package
    ) -> String {
        if package.version != "unspecified",
           package.url.contains("://"),
           !package.url.hasPrefix("file://") {
            return "url: \"\(swiftString(package.url))\", exact: \"\(swiftString(package.version))\""
        }
        return "path: \"\(swiftString(package.directory.path))\""
    }

    private func swiftString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func copyTemplate(
        _ template: SwiftWebAdapterManifest.Template,
        adapterDirectory: URL,
        workspaceDirectory: URL,
        substitutions: [String: String],
        managedPaths: inout Set<String>
    ) throws {
        let source = try safeRelativeURL(template.source, under: adapterDirectory)
        let destination = try safeRelativeURL(template.destination, under: workspaceDirectory)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SwiftWebLifecycleError.missingTemplate(source)
        }
        try copyDirectory(
            from: source,
            to: destination,
            sourceRoot: source,
            workspaceDirectory: workspaceDirectory,
            substitutions: substitutions,
            excludedPaths: [],
            managedPaths: &managedPaths
        )
    }

    private func copyDirectory(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        sourceRoot: URL,
        workspaceDirectory: URL,
        substitutions: [String: String],
        excludedPaths: [String],
        managedPaths: inout Set<String>
    ) throws {
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        let children = try FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )
        for child in children {
            let sourceRelativePath = try relativePath(child, under: sourceRoot)
            guard !isExcluded(sourceRelativePath, by: excludedPaths) else {
                continue
            }
            let values = try child.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                throw SwiftWebLifecycleError.unsafeTemplateEntry(child)
            }
            let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
            if values.isDirectory == true {
                try copyDirectory(
                    from: child,
                    to: destination,
                    sourceRoot: sourceRoot,
                    workspaceDirectory: workspaceDirectory,
                    substitutions: substitutions,
                    excludedPaths: excludedPaths,
                    managedPaths: &managedPaths
                )
                continue
            }
            guard values.isRegularFile == true else {
                throw SwiftWebLifecycleError.unsafeTemplateEntry(child)
            }
            let data = try Data(contentsOf: child)
            let nextData: Data
            if let text = String(data: data, encoding: .utf8) {
                nextData = Data(render(text, substitutions: substitutions).utf8)
            } else {
                nextData = data
            }
            try writeIfChanged(nextData, to: destination)
            if let permissions = try FileManager.default.attributesOfItem(atPath: child.path)[.posixPermissions] {
                try FileManager.default.setAttributes(
                    [.posixPermissions: permissions],
                    ofItemAtPath: destination.path
                )
            }
            managedPaths.insert(try relativePath(destination, under: workspaceDirectory))
        }
    }

    private func removeStaleManagedPaths(
        rootDirectory: URL,
        workspaceDirectory: URL,
        nextManagedPaths: Set<String>
    ) throws {
        let recordURL = rootDirectory.appendingPathComponent("materialization.json")
        guard FileManager.default.fileExists(atPath: recordURL.path) else {
            return
        }
        let record = try JSONDecoder().decode(
            MaterializationRecord.self,
            from: Data(contentsOf: recordURL)
        )
        for stalePath in Set(record.managedPaths).subtracting(nextManagedPaths) {
            let staleURL = try safeRelativeURL(stalePath, under: workspaceDirectory)
            if FileManager.default.fileExists(atPath: staleURL.path) {
                try FileManager.default.removeItem(at: staleURL)
            }
        }
    }

    private func writeMaterializationRecord(
        _ managedPaths: Set<String>,
        rootDirectory: URL
    ) throws {
        let record = MaterializationRecord(
            schemaVersion: 1,
            managedPaths: managedPaths.sorted()
        )
        try writeJSON(record, to: rootDirectory.appendingPathComponent("materialization.json"))
    }

    private func writePlanLock(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment,
        rootDirectory: URL
    ) throws {
        func component(
            adapter: SwiftWebProjectResolution.Adapter,
            name: String
        ) -> PlanLock.Component {
            PlanLock.Component(
                adapter: adapter.manifest.id,
                name: name,
                packageIdentity: adapter.package.identity,
                version: adapter.package.version,
                path: adapter.directory.path
            )
        }
        let lock = PlanLock(
            schemaVersion: 1,
            environment: environment.name,
            applicationProduct: resolution.manifest.application.product,
            applicationType: resolution.manifest.application.type,
            host: component(adapter: environment.hostAdapter, name: environment.hostName),
            deployment: component(
                adapter: environment.deploymentAdapter,
                name: environment.deploymentName
            )
        )
        try writeJSON(lock, to: rootDirectory.appendingPathComponent("plan.lock.json"))
    }

    private func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try writeIfChanged(data, to: url)
    }

    private func writeIfChanged(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path),
           try Data(contentsOf: url) == data {
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func render(_ text: String, substitutions: [String: String]) -> String {
        substitutions.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
    }

    private func safeRelativeURL(_ relativePath: String, under root: URL) throws -> URL {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) || relativePath.isEmpty else {
            throw SwiftWebLifecycleError.invalidTemplatePath(relativePath)
        }
        return relativePath.isEmpty
            ? root.standardizedFileURL
            : root.appendingPathComponent(relativePath).standardizedFileURL
    }

    private func relativePath(_ url: URL, under root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidatePath.hasPrefix(prefix) else {
            throw SwiftWebLifecycleError.invalidTemplatePath(candidatePath)
        }
        return String(candidatePath.dropFirst(prefix.count))
    }

    private func isExcluded(_ path: String, by excludedPaths: [String]) -> Bool {
        excludedPaths.contains { excluded in
            path == excluded || path.hasPrefix(excluded + "/")
        }
    }

    private static func kebabCase(_ value: String) -> String {
        var result = ""
        for character in value {
            if character.isUppercase, !result.isEmpty {
                result.append("-")
            }
            result.append(character.lowercased())
        }
        return result
    }
}
