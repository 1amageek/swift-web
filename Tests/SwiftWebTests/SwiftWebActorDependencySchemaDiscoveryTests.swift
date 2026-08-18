import ActorSystemGeneration
import Foundation
import Testing

@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebActorDependencySchemaDiscoveryTests {
    @Test
    func discoversDependencyModulesInDependencyFirstOrder() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let shared = root.appendingPathComponent("Shared", isDirectory: true)
        let common = root.appendingPathComponent("Common", isDirectory: true)
        try writePackage(named: "App", dependencies: [shared], to: app)
        try writePackage(named: "Shared", dependencies: [common], to: shared)
        try writePackage(named: "Common", dependencies: [], to: common)
        try writeActorModule(
            moduleName: "CommonActors",
            importedModule: nil,
            packageIdentity: "common",
            packageDirectory: common,
            typeID: 1
        )
        try writeActorModule(
            moduleName: "SharedActors",
            importedModule: "CommonActors",
            packageIdentity: "shared",
            packageDirectory: shared,
            typeID: 2
        )
        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedActors"]),
            .init(moduleName: "SharedActors", packageRoot: shared, dependencies: ["CommonActors"]),
            .init(moduleName: "CommonActors", packageRoot: common, dependencies: []),
        ])

        let modules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
            importedModules: ["SharedActors"],
            appModuleName: "App",
            targetGraph: graph,
            targetEnvironment: try embeddedEnvironment()
        )

        #expect(modules.map { $0.schema.moduleName } == ["CommonActors", "SharedActors"])
        #expect(modules[0].dependencyModuleNames.isEmpty)
        #expect(modules[1].dependencyModuleNames == ["CommonActors"])
    }

    @Test
    func discoversActiveImportsRetainedByDependencyClientProjection() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let shared = root.appendingPathComponent("Shared", isDirectory: true)
        let common = root.appendingPathComponent("Common", isDirectory: true)
        try writePackage(named: "App", dependencies: [shared], to: app)
        try writePackage(named: "Shared", dependencies: [common], to: shared)
        try writePackage(named: "Common", dependencies: [], to: common)
        try writeActorModule(
            moduleName: "CommonActors",
            importedModule: nil,
            packageIdentity: "common",
            packageDirectory: common,
            typeID: 1
        )
        try writeActorModule(
            moduleName: "HostOnlyActors",
            importedModule: nil,
            packageIdentity: "common",
            packageDirectory: common,
            typeID: 2
        )
        try writeActorModule(
            moduleName: "SharedActors",
            importedModule: nil,
            packageIdentity: "shared",
            packageDirectory: shared,
            typeID: 3
        )
        try write(
            """
            #if hasFeature(Embedded)
            import CommonActors
            #else
            import HostOnlyActors
            #endif

            public struct SharedClientHelper {}
            """,
            to: shared.appendingPathComponent(
                "Sources/SharedActors/SharedClientHelper.swift"
            )
        )
        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedActors"]),
            .init(
                moduleName: "SharedActors",
                packageRoot: shared,
                dependencies: ["CommonActors", "HostOnlyActors"]
            ),
            .init(moduleName: "CommonActors", packageRoot: common, dependencies: []),
            .init(moduleName: "HostOnlyActors", packageRoot: common, dependencies: []),
        ])

        let modules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
            importedModules: ["SharedActors"],
            appModuleName: "App",
            targetGraph: graph,
            targetEnvironment: try embeddedEnvironment()
        )

        #expect(modules.map { $0.schema.moduleName } == ["CommonActors", "SharedActors"])
        #expect(modules[1].dependencyModuleNames == ["CommonActors"])
        #expect(modules[1].clientImportedModuleNames.contains("CommonActors"))
        #expect(!modules[1].clientImportedModuleNames.contains("HostOnlyActors"))
    }

    @Test
    func declaredDependencyConditionSelectsTheSameBranchThatTheGeneratedTargetDefines() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let shared = root.appendingPathComponent("Shared", isDirectory: true)
        let common = root.appendingPathComponent("Common", isDirectory: true)
        try writePackage(named: "App", dependencies: [shared], to: app)
        try writePackage(named: "Shared", dependencies: [common], to: shared)
        try writePackage(named: "Common", dependencies: [], to: common)
        try writeActorModule(
            moduleName: "CommonActors",
            importedModule: nil,
            packageIdentity: "common",
            packageDirectory: common,
            typeID: 1
        )
        try writeActorModule(
            moduleName: "HostOnlyActors",
            importedModule: nil,
            packageIdentity: "common",
            packageDirectory: common,
            typeID: 2
        )
        try writeActorModule(
            moduleName: "SharedActors",
            importedModule: nil,
            packageIdentity: "shared",
            packageDirectory: shared,
            typeID: 3
        )
        try write(
            """
            #if SHARED_CLIENT
            import CommonActors
            #else
            import HostOnlyActors
            #endif

            public struct SharedClientHelper {}
            """,
            to: shared.appendingPathComponent(
                "Sources/SharedActors/SharedClientHelper.swift"
            )
        )
        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedActors"]),
            .init(
                moduleName: "SharedActors",
                packageRoot: shared,
                dependencies: ["CommonActors", "HostOnlyActors"],
                customConditions: ["SHARED_CLIENT"]
            ),
            .init(moduleName: "CommonActors", packageRoot: common, dependencies: []),
            .init(moduleName: "HostOnlyActors", packageRoot: common, dependencies: []),
        ])

        let modules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
            importedModules: ["SharedActors"],
            appModuleName: "App",
            targetGraph: graph,
            targetEnvironment: try embeddedEnvironment()
        )

        #expect(modules.map { $0.schema.moduleName } == ["CommonActors", "SharedActors"])
        #expect(modules[1].customConditions == ["SHARED_CLIENT"])
        #expect(modules[1].clientImportedModuleNames.contains("CommonActors"))
        #expect(!modules[1].clientImportedModuleNames.contains("HostOnlyActors"))
    }

    @Test
    func rejectsImportedSchemaWithoutADirectTargetEdge() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let first = root.appendingPathComponent("First", isDirectory: true)
        let second = root.appendingPathComponent("Second", isDirectory: true)
        try writePackage(named: "App", dependencies: [first], to: app)
        try writePackage(named: "First", dependencies: [second], to: first)
        try writePackage(named: "Second", dependencies: [], to: second)
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: "second",
                moduleName: "SharedModels"
            ),
            to: second.appendingPathComponent("ActorSchemas/shared.lock")
        )
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: "first",
                moduleName: "IgnoredModels"
            ),
            to: first.appendingPathComponent("ActorSchema.lock")
        )

        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["IgnoredModels"]),
            .init(moduleName: "IgnoredModels", packageRoot: first, dependencies: ["SharedModels"]),
            .init(moduleName: "SharedModels", packageRoot: second, dependencies: []),
        ])
        #expect(throws: ActorGenerationError.self) {
            _ = try SwiftWebActorDependencySchemaDiscovery.discover(
                importedModules: ["Foundation", "SharedModels"],
                appModuleName: "App",
                targetGraph: graph
            )
        }
    }

    @Test
    func ignoresSwiftFilesOutsideTheEvaluatedTargetSourceSet() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let shared = root.appendingPathComponent("Shared", isDirectory: true)
        try writePackage(named: "App", dependencies: [shared], to: app)
        try writePackage(named: "Shared", dependencies: [], to: shared)
        try writeActorModule(
            moduleName: "SharedActors",
            importedModule: nil,
            packageIdentity: "shared",
            packageDirectory: shared,
            typeID: 1
        )
        let sharedSourceDirectory = shared.appendingPathComponent(
            "Sources/SharedActors",
            isDirectory: true
        )
        try write(
            """
            #if hasFeature(Embedded)
            import Foundation
            #endif

            struct ExcludedServerValue: Codable {
                let secret: String
            }
            """,
            to: sharedSourceDirectory.appendingPathComponent("ExcludedServer.swift")
        )
        let includedActorSource = sharedSourceDirectory.appendingPathComponent(
            "FixtureActor.swift"
        )
        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedActors"]),
            .init(
                moduleName: "SharedActors",
                packageRoot: shared,
                sourceFiles: [includedActorSource],
                dependencies: []
            ),
        ])

        let modules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
            importedModules: ["SharedActors"],
            appModuleName: "App",
            targetGraph: graph,
            targetEnvironment: try embeddedEnvironment()
        )

        #expect(modules.count == 1)
        #expect(modules[0].sourceFiles == [includedActorSource.standardizedFileURL])
    }

    @Test
    func discoversSchemaFromResolvedCheckout() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let checkout = app.appendingPathComponent(
            ".build/checkouts/shared-package",
            isDirectory: true
        )
        try writePackage(named: "App", dependencies: [], to: app)
        try writePackage(named: "shared-package", dependencies: [], to: checkout)
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: "shared-package",
                moduleName: "SharedModels"
            ),
            to: checkout.appendingPathComponent(
                "Sources/SharedModels/ActorSchema.lock"
            )
        )

        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedModels"]),
            .init(moduleName: "SharedModels", packageRoot: checkout, dependencies: []),
        ])
        let schemas = try SwiftWebActorDependencySchemaDiscovery.discover(
            importedModules: ["SharedModels"],
            appModuleName: "App",
            targetGraph: graph
        )

        #expect(schemas.map(\.moduleName) == ["SharedModels"])
    }

    @Test
    func discoversActorSourcesAtTheEvaluatedCustomTargetPath() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let dependency = root.appendingPathComponent("Dependency", isDirectory: true)
        let customSourceDirectory = dependency.appendingPathComponent(
            "CustomSources/SharedActors",
            isDirectory: true
        )
        try writePackage(named: "App", dependencies: [dependency], to: app)
        try writePackage(named: "Dependency", dependencies: [], to: dependency)
        try writeActorModule(
            moduleName: "SharedActors",
            importedModule: nil,
            packageIdentity: "dependency",
            packageDirectory: dependency,
            sourceRelativePath: "CustomSources/SharedActors",
            typeID: 1
        )
        let graph = try targetGraph([
            .init(moduleName: "App", packageRoot: app, dependencies: ["SharedActors"]),
            .init(
                moduleName: "SharedActors",
                packageRoot: dependency,
                sourceDirectory: customSourceDirectory,
                dependencies: []
            ),
        ])

        let modules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
            importedModules: ["SharedActors"],
            appModuleName: "App",
            targetGraph: graph,
            targetEnvironment: try embeddedEnvironment()
        )

        #expect(modules.map { $0.sourceDirectory } == [customSourceDirectory.standardizedFileURL])
    }

    @Test
    func rejectsDuplicateModulesInTheEvaluatedTargetGraph() throws {
        let root = temporaryDirectory()
        defer { removeDirectory(root) }

        let app = root.appendingPathComponent("App", isDirectory: true)
        let first = root.appendingPathComponent("First", isDirectory: true)
        let second = root.appendingPathComponent("Second", isDirectory: true)
        try writePackage(named: "App", dependencies: [first, second], to: app)
        try writePackage(named: "First", dependencies: [], to: first)
        try writePackage(named: "Second", dependencies: [], to: second)
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: "first",
                moduleName: "SharedModels"
            ),
            to: first.appendingPathComponent("ActorSchema.lock")
        )
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: "second",
                moduleName: "SharedModels"
            ),
            to: second.appendingPathComponent("ActorSchema.lock")
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try targetGraph([
                .init(moduleName: "App", packageRoot: app, dependencies: ["SharedModels"]),
                .init(moduleName: "SharedModels", packageRoot: first, dependencies: []),
                .init(moduleName: "SharedModels", packageRoot: second, dependencies: []),
            ])
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "SwiftWebActorDependencySchemaDiscoveryTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private struct TargetFixture {
        let moduleName: String
        let packageRoot: URL
        let sourceDirectory: URL?
        let sourceFiles: [URL]?
        let dependencies: Set<String>
        let customConditions: Set<String>
        let upcomingFeatures: Set<String>
        let experimentalFeatures: Set<String>

        init(
            moduleName: String,
            packageRoot: URL,
            sourceDirectory: URL? = nil,
            sourceFiles: [URL]? = nil,
            dependencies: Set<String>,
            customConditions: Set<String> = [],
            upcomingFeatures: Set<String> = [],
            experimentalFeatures: Set<String> = []
        ) {
            self.moduleName = moduleName
            self.packageRoot = packageRoot
            self.sourceDirectory = sourceDirectory
            self.sourceFiles = sourceFiles
            self.dependencies = dependencies
            self.customConditions = customConditions
            self.upcomingFeatures = upcomingFeatures
            self.experimentalFeatures = experimentalFeatures
        }
    }

    private func targetGraph(
        _ fixtures: [TargetFixture]
    ) throws -> SwiftWebEvaluatedPackageTargetGraph {
        try SwiftWebEvaluatedPackageTargetGraph(
            targets: try fixtures.map {
                let sourceDirectory = $0.sourceDirectory ?? $0.packageRoot
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent($0.moduleName, isDirectory: true)
                let sourceFiles: [URL]
                if let declaredSourceFiles = $0.sourceFiles {
                    sourceFiles = declaredSourceFiles
                } else {
                    sourceFiles = try swiftSourceFiles(in: sourceDirectory)
                }
                return .init(
                    moduleName: $0.moduleName,
                    packageRoot: $0.packageRoot,
                    sourceDirectory: sourceDirectory,
                    sourceFiles: sourceFiles,
                    directDependencyModuleNames: $0.dependencies,
                    customConditions: $0.customConditions,
                    upcomingFeatures: $0.upcomingFeatures,
                    experimentalFeatures: $0.experimentalFeatures
                )
            }
        )
    }

    private func swiftSourceFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var sources: [URL] = []
        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                sources.append(contentsOf: try swiftSourceFiles(in: child))
            } else if child.pathExtension == "swift" {
                sources.append(child.standardizedFileURL)
            }
        }
        return sources.sorted { $0.path < $1.path }
    }

    private func embeddedEnvironment() throws -> ActorGenerationTargetEnvironment {
        try ActorGenerationTargetEnvironment(
            availableModules: [
                "ActorSystemCore", "ActorSystemEmbedded", "Swift",
            ],
            features: ["Embedded"],
            operatingSystem: "WASI",
            architecture: "wasm32",
            objectFormat: "wasm",
            pointerBitWidth: 32,
            atomicBitWidths: [8, 16, 32, 64],
            languageVersion: [6],
            compilerVersion: [6, 4]
        )
    }

    private func removeDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove temporary directory: \(error)")
        }
    }

    private func writePackage(
        named name: String,
        dependencies: [URL],
        to directory: URL
    ) throws {
        let dependencyDeclarations = dependencies.map { dependency in
            ".package(path: \"\(dependency.path)\")"
        }.joined(separator: ",\n        ")
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "\(name)",
                dependencies: [
                    \(dependencyDeclarations)
                ],
                targets: []
            )
            """,
            to: directory.appendingPathComponent("Package.swift")
        )
    }

    private func writeActorModule(
        moduleName: String,
        importedModule: String?,
        packageIdentity: String,
        packageDirectory: URL,
        sourceRelativePath: String? = nil,
        typeID: UInt64
    ) throws {
        let sourceDirectory: URL
        if let sourceRelativePath {
            sourceDirectory = packageDirectory.appendingPathComponent(
                sourceRelativePath,
                isDirectory: true
            )
        } else {
            sourceDirectory = packageDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(moduleName, isDirectory: true)
        }
        let importedDeclaration = importedModule.map { "import \($0)\n" } ?? ""
        try write(
            """
            import Distributed
            \(importedDeclaration)
            distributed actor FixtureActor {
                typealias ActorSystem = SwiftActorSystem

                distributed func value() async throws -> Int { 0 }
            }
            """,
            to: sourceDirectory.appendingPathComponent("FixtureActor.swift")
        )
        let actor = ActorSchemaLockActor(
            moduleName: moduleName,
            sourceSymbol: "\(moduleName).FixtureActor",
            sourcePath: sourceDirectory.appendingPathComponent("FixtureActor.swift").path,
            typeID: ActorSchemaLockID128(high: 0, low: typeID),
            schemaFingerprint: ActorSchemaLockID128(high: 1, low: typeID),
            methods: [],
            fields: [],
            reservedFieldIDs: []
        )
        try ActorSchemaLockStore.save(
            ActorSchemaLock(
                packageIdentity: packageIdentity,
                moduleName: moduleName,
                actors: [actor]
            ),
            to: sourceDirectory.appendingPathComponent("ActorSchema.lock")
        )
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
