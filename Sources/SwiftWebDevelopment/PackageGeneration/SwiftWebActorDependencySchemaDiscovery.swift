import ActorSystemGeneration
import Foundation
import SwiftParser
import SwiftSyntax

package struct SwiftWebActorDependencyModule: Sendable {
    package let schema: ActorSchemaLock
    package let packageRoot: URL
    package let schemaURL: URL
    package let sourceDirectory: URL
    package let sourceFiles: [URL]
    package let dependencyModuleNames: [String]
    package let clientImportedModuleNames: [String]
    package let customConditions: Set<String>
    package let upcomingFeatures: Set<String>
    package let experimentalFeatures: Set<String>
    package let targetEnvironment: ActorGenerationTargetEnvironment
}

package enum SwiftWebActorDependencySchemaDiscovery {
    private struct LocatedSchema {
        let lock: ActorSchemaLock
        let url: URL
        let packageRoot: URL
        let sourceDirectory: URL
    }

    private struct SchemaIndex {
        var schemas: [String: LocatedSchema] = [:]
        var conflicts: [String: (first: URL, second: URL)] = [:]
    }

    package static func directActorSchemaModuleNames(
        appModuleName: String,
        targetGraph: SwiftWebEvaluatedPackageTargetGraph
    ) throws -> Set<String> {
        let directDependencies = try targetGraph.directDependencyModuleNames(
            of: appModuleName
        )
        let index = try indexedSchemas(targetGraph: targetGraph)
        return directDependencies.intersection(Set(index.schemas.keys))
    }

    package static func discover(
        importedModules: Set<String>,
        appModuleName: String,
        targetGraph: SwiftWebEvaluatedPackageTargetGraph
    ) throws -> [ActorSchemaLock] {
        let requestedModules = importedModules.subtracting([appModuleName])
        let directDependencies = try targetGraph.directDependencyModuleNames(
            of: appModuleName
        )
        let index = try indexedSchemas(targetGraph: targetGraph)
        for moduleName in requestedModules {
            try validateNoConflict(moduleName, in: index)
            if index.schemas[moduleName] != nil,
               !directDependencies.contains(moduleName) {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor schema module \(moduleName) is imported by \(appModuleName) without a direct SwiftPM target dependency"
                )
            }
        }
        return requestedModules.intersection(directDependencies)
          .compactMap { index.schemas[$0]?.lock }.sorted {
            if $0.packageIdentity == $1.packageIdentity {
                return $0.moduleName < $1.moduleName
            }
            return $0.packageIdentity < $1.packageIdentity
        }
    }

    package static func discoverModules(
        importedModules: Set<String>,
        appModuleName: String,
        targetGraph: SwiftWebEvaluatedPackageTargetGraph,
        targetEnvironment: ActorGenerationTargetEnvironment
    ) throws -> [SwiftWebActorDependencyModule] {
        let requestedModules = importedModules.subtracting([appModuleName])
        guard !requestedModules.isEmpty else {
            return []
        }

        let rootDependencies = try targetGraph.directDependencyModuleNames(
            of: appModuleName
        )
        let index = try indexedSchemas(targetGraph: targetGraph)
        let schemasByModule = index.schemas
        for moduleName in requestedModules where schemasByModule[moduleName] != nil {
            guard rootDependencies.contains(moduleName) else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor schema module \(moduleName) is imported by \(appModuleName) without a direct SwiftPM target dependency"
                )
            }
        }
        var pending = requestedModules.intersection(rootDependencies).sorted()
        var selected: [String: SwiftWebActorDependencyModule] = [:]
        while !pending.isEmpty {
            let moduleName = pending.removeFirst()
            try validateNoConflict(moduleName, in: index)
            guard selected[moduleName] == nil,
                  let located = schemasByModule[moduleName]
            else {
                continue
            }
            let sourceDirectory = try sourceDirectory(for: located)
            guard let declaredTarget = targetGraph.target(named: moduleName) else {
                throw ActorGenerationError.schemaConflict(
                    reason: "SwiftPM target graph has no actor dependency target named \(moduleName)"
                )
            }
            try declaredTarget.validateGeneratedProjectionCapabilities()
            let sourceFiles = declaredTarget.sourceFiles.filter {
                !$0.pathComponents.contains("ActorSystemGenerated")
            }
            guard !sourceFiles.isEmpty || located.lock.actors.isEmpty else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor schema module \(moduleName) has no Swift sources at \(sourceDirectory.path)"
                )
            }
            let declaredDependencies = try targetGraph.directDependencyModuleNames(
                of: moduleName
            )
            let actorDependencyNames = declaredDependencies
                .intersection(Set(schemasByModule.keys))
                .subtracting([moduleName])
            let moduleEnvironment = try targetEnvironment
                .addingAvailableModules(actorDependencyNames)
                .addingBuildConditions(
                    customConditions: declaredTarget.customConditions,
                    features: declaredTarget.features
                )
            let actors = try ActorSourceScanner.scan(
                sourceFiles: sourceFiles,
                moduleName: moduleName,
                includingActorSymbols: Set(located.lock.actors.map(\.sourceSymbol)),
                targetEnvironment: moduleEnvironment
            )
            let boundaryImports = try ActorBoundaryImportAnalyzer.importedModules(
                actors: actors,
                sourceFiles: sourceFiles,
                moduleName: moduleName,
                targetEnvironment: moduleEnvironment
            )
            let clientSourceImports = try importedClientSourceModules(
                sourceFiles: sourceFiles,
                sourceDirectory: sourceDirectory,
                targetEnvironment: moduleEnvironment
            )
            let generatedActorImports = Set(actors.flatMap(\.imports))
            let undeclaredImports = clientSourceImports
                .subtracting(generatedActorImports)
                .subtracting(moduleEnvironment.availableModules)
                .subtracting([moduleName])
            guard undeclaredImports.isEmpty else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor dependency target \(moduleName) imports modules unavailable to the generated target: \(undeclaredImports.sorted().joined(separator: ", "))"
                )
            }
            let dependencyNames = Array(
                boundaryImports.union(clientSourceImports)
                    .intersection(actorDependencyNames)
                    .subtracting(Set([moduleName]))
            ).sorted()
            selected[moduleName] = SwiftWebActorDependencyModule(
                schema: located.lock,
                packageRoot: located.packageRoot,
                schemaURL: located.url,
                sourceDirectory: sourceDirectory,
                sourceFiles: sourceFiles,
                dependencyModuleNames: dependencyNames,
                clientImportedModuleNames: clientSourceImports.sorted(),
                customConditions: declaredTarget.customConditions,
                upcomingFeatures: declaredTarget.upcomingFeatures,
                experimentalFeatures: declaredTarget.experimentalFeatures,
                targetEnvironment: moduleEnvironment
            )
            pending.append(contentsOf: dependencyNames)
            pending.sort()
        }

        var ordered: [SwiftWebActorDependencyModule] = []
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ moduleName: String) throws {
            guard !visited.contains(moduleName), let module = selected[moduleName] else {
                return
            }
            guard visiting.insert(moduleName).inserted else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor schema dependency cycle includes \(moduleName)"
                )
            }
            for dependency in module.dependencyModuleNames {
                try visit(dependency)
            }
            visiting.remove(moduleName)
            visited.insert(moduleName)
            ordered.append(module)
        }
        for moduleName in selected.keys.sorted() {
            try visit(moduleName)
        }
        return ordered
    }

    private static func importedClientSourceModules(
        sourceFiles: [URL],
        sourceDirectory: URL,
        targetEnvironment: ActorGenerationTargetEnvironment
    ) throws -> Set<String> {
        var modules = Set<String>()
        let sourceRootPath = sourceDirectory.standardizedFileURL.path
        for sourceURL in sourceFiles {
            let sourcePath = sourceURL.standardizedFileURL.path
            let prefix = sourceRootPath.hasSuffix("/")
                ? sourceRootPath
                : sourceRootPath + "/"
            guard sourcePath.hasPrefix(prefix) else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor dependency source \(sourcePath) is outside \(sourceRootPath)"
                )
            }
            let relativePath = String(sourcePath.dropFirst(prefix.count))
            guard !GeneratedSourcePathPolicy.isServerOnlyActorDependency(
                relativePath: relativePath
            ) else {
                continue
            }

            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let syntax = Parser.parse(source: source)
            modules.formUnion(
                try ActorProfileConditionResolver.importedModules(
                    in: syntax,
                    environment: targetEnvironment,
                    symbol: relativePath
                )
            )
        }
        return modules
    }

    private static func indexedSchemas(
        targetGraph: SwiftWebEvaluatedPackageTargetGraph
    ) throws -> SchemaIndex {
        var index = SchemaIndex()
        let targetsByRoot = Dictionary(grouping: targetGraph.targets) {
            $0.packageRoot.standardizedFileURL
        }
        for root in targetsByRoot.keys.sorted(by: { $0.path < $1.path }) {
            let declaredTargets = targetsByRoot[root] ?? []
            for schemaURL in try schemaURLs(
                in: root,
                targetSourceDirectories: declaredTargets.map(\.sourceDirectory)
            ) {
                let data = try Data(contentsOf: schemaURL)
                let lock = try ActorSchemaLockStore.decode(data)
                guard let declaredTarget = targetGraph.target(named: lock.moduleName),
                      declaredTarget.packageRoot.standardizedFileURL == root
                else {
                    continue
                }
                let candidate = LocatedSchema(
                    lock: lock,
                    url: schemaURL,
                    packageRoot: root,
                    sourceDirectory: declaredTarget.sourceDirectory
                )
                if let existing = index.schemas[lock.moduleName] {
                    if existing.lock != lock {
                        index.conflicts[lock.moduleName] = (
                            first: existing.url,
                            second: schemaURL
                        )
                    } else if optionalSourceDirectory(for: existing) == nil,
                              optionalSourceDirectory(for: candidate) != nil {
                        index.schemas[lock.moduleName] = candidate
                    }
                    continue
                }
                index.schemas[lock.moduleName] = candidate
            }
        }
        return index
    }

    private static func validateNoConflict(
        _ moduleName: String,
        in index: SchemaIndex
    ) throws {
        guard let conflict = index.conflicts[moduleName] else {
            return
        }
        throw ActorGenerationError.schemaConflict(
            reason: "Imported actor schema module \(moduleName) has conflicting definitions at \(conflict.first.path) and \(conflict.second.path)"
        )
    }

    private static func sourceDirectory(
        for located: LocatedSchema
    ) throws -> URL {
        guard let directory = optionalSourceDirectory(for: located) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Cannot locate source target \(located.lock.moduleName) for actor schema at \(located.url.path)"
            )
        }
        return directory
    }

    private static func optionalSourceDirectory(
        for located: LocatedSchema
    ) -> URL? {
        return FileManager.default.fileExists(atPath: located.sourceDirectory.path)
            ? located.sourceDirectory
            : nil
    }

    private static func schemaURLs(
        in packageRoot: URL,
        targetSourceDirectories: [URL]
    ) throws -> [URL] {
        var candidates = [packageRoot.appendingPathComponent("ActorSchema.lock")]

        let schemasDirectory = packageRoot.appendingPathComponent(
            "ActorSchemas",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: schemasDirectory.path) {
            let files = try FileManager.default.contentsOfDirectory(
                at: schemasDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            candidates.append(
                contentsOf: files.filter { $0.pathExtension == "lock" }
            )
        }

        candidates.append(contentsOf: targetSourceDirectories.map {
            $0.appendingPathComponent("ActorSchema.lock")
        })

        var seenPaths = Set<String>()
        return candidates
            .map(\.standardizedFileURL)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .filter { seenPaths.insert($0.path).inserted }
            .sorted { $0.path < $1.path }
    }
}
