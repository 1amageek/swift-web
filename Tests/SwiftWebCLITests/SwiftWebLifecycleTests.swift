import Foundation
import XCTest

@testable import SwiftWebCLI

final class SwiftWebLifecycleTests: XCTestCase {
    func testLifecycleCommandSelectsEmbeddedRuntime() throws {
        let command = try LifecycleCommand.parse(
            ArgumentParser(arguments: ["--runtime", "embedded"]),
            operation: .build
        )

        XCTAssertEqual(command.wasmRuntimeProfile, .embedded)
    }

    func testDevelopmentLifecycleRejectsEmbeddedRuntime() {
        XCTAssertThrowsError(
            try LifecycleCommand.parse(
                ArgumentParser(arguments: ["--runtime", "embedded"]),
                operation: .dev
            )
        )
    }

    func testHostBuildInvocationRejectsAnUnpinnedCompilerOverride() {
        XCTAssertThrowsError(
            try SwiftBuildInvocation.host(
                packageDirectory: FileManager.default.temporaryDirectory,
                environment: ["SWIFT_WEB_HOST_SWIFT": "/usr/bin/false"]
            )
        )
    }

    func testDevelopmentLifecycleBuildsOnlyTheDevelopmentServer() {
        XCTAssertEqual(
            SwiftWebProjectLifecycle.operations(for: .dev),
            [.prepare, .dev]
        )
    }

    func testLifecycleCommandCancellationTerminatesDescendants() async throws {
        try await withTemporaryDirectory { root in
            let descendantPIDFile = root.appendingPathComponent("descendant.pid")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                "-c",
                "sleep 30 & echo $! > \"$1\"; wait",
                "command",
                descendantPIDFile.path,
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            let command = Task {
                try await SwiftWebLifecycleCommandRunner().run(process)
            }
            let descendantPID = try await waitForProcessIdentifier(in: descendantPIDFile)
            command.cancel()

            do {
                _ = try await command.value
                XCTFail("Expected lifecycle command cancellation")
            } catch is CancellationError {
                // Expected.
            }

            let descendantExited = try await waitForProcessExit(descendantPID)
            XCTAssertTrue(descendantExited)
        }
    }

    func testTerseManifestsDecodeWithStructuralDefaults() throws {
        let project = try JSONDecoder().decode(
            SwiftWebProjectManifest.self,
            from: Data(
                """
                {
                  "schemaVersion": 3,
                  "application": { "product": "Calendar", "type": "CalendarApp" },
                  "environments": {
                    "production": {
                      "host": "cloud/worker",
                      "deployment": "cloud/workers"
                    }
                  },
                  "defaults": { "build": "production", "deploy": "production" }
                }
                """.utf8
            )
        )
        let adapter = try JSONDecoder().decode(
            SwiftWebAdapterManifest.self,
            from: Data(
                """
                {
                  "schemaVersion": 3,
                  "kind": "adapter",
                  "id": "cloud",
                  "defaults": { "host": "worker", "deployment": "workers" },
                  "hosts": {
                    "worker": { "produces": ["swiftweb.wasm-module"] }
                  },
                  "deployments": {
                    "workers": { "accepts": ["swiftweb.wasm-module"] }
                  }
                }
                """.utf8
            )
        )

        XCTAssertNil(project.application.module)
        XCTAssertTrue(project.environments["production"]?.overlays.isEmpty == true)
        XCTAssertTrue(project.environments["production"]?.operations.isEmpty == true)
        XCTAssertTrue(project.services.isEmpty)
        XCTAssertTrue(adapter.hosts["worker"]?.templates.isEmpty == true)
        XCTAssertTrue(adapter.deployments["workers"]?.operations.isEmpty == true)
        XCTAssertTrue(
            adapter.deployments["workers"]?.acceptsServiceArtifacts.isEmpty == true
        )
        XCTAssertTrue(adapter.services.isEmpty)
    }

    func testProjectActorDeclarationRejectsManifestOwnedIdentity() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                SwiftWebProjectManifest.Service.Actor.self,
                from: Data(
                    """
                    {
                      "product": "CalendarActorContract",
                      "module": "CalendarActorContract",
                      "type": "CalendarDatabaseActor",
                      "identity": "production"
                    }
                    """.utf8
                )
            )
        )
    }

    func testAdapterActorBindingRejectsArbitrarySwiftSource() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                SwiftWebAdapterManifest.Deployment.ActorBinding.self,
                from: Data(
                    """
                    {
                      "hostRoute": {
                        "transport": "swiftweb.http",
                        "endpointPrefix": "cloudflare-do://database/"
                      },
                      "swiftExpression": "UnsafeBinding()"
                    }
                    """.utf8
                )
            )
        )
    }

    func testResolverSelectsDirectPackageAdaptersAndChecksArtifacts() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let framework = root.appendingPathComponent("swift-web", isDirectory: true)
            let cloud = root.appendingPathComponent("cloud", isDirectory: true)
            try writeProjectManifest(at: app, host: "swift-web/http-server", deployment: "cloud/workers")
            try writeAdapterManifest(
                at: framework,
                id: "swift-web",
                host: "http-server",
                produces: ["swiftweb.server-executable"],
                deployment: "local",
                accepts: ["swiftweb.server-executable"]
            )
            try writeAdapterManifest(
                at: cloud,
                id: "cloud",
                host: "worker",
                produces: ["swiftweb.server-executable"],
                deployment: "workers",
                accepts: ["swiftweb.server-executable"]
            )
            let graph = makeGraph(root: app, dependencies: [framework, cloud])
            let resolution = try await SwiftWebProjectResolver(
                graphLoader: StaticDependencyGraphLoader(graph: graph)
            ).resolve(packageDirectory: app)
            let environment = try resolution.environment(named: "production")

            XCTAssertEqual(environment.hostAdapter.manifest.id, "swift-web")
            XCTAssertEqual(environment.hostName, "http-server")
            XCTAssertEqual(environment.deploymentAdapter.manifest.id, "cloud")
            XCTAssertEqual(environment.deploymentName, "workers")
        }
    }

    func testResolverRejectsIncompatibleHostAndDeploymentArtifacts() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let cloud = root.appendingPathComponent("cloud", isDirectory: true)
            try writeProjectManifest(at: app, host: "cloud/worker", deployment: "cloud/workers")
            try writeAdapterManifest(
                at: cloud,
                id: "cloud",
                host: "worker",
                produces: ["swiftweb.wasm-module"],
                deployment: "workers",
                accepts: ["swiftweb.container-image"]
            )
            let resolution = try await SwiftWebProjectResolver(
                graphLoader: StaticDependencyGraphLoader(
                    graph: makeGraph(root: app, dependencies: [cloud])
                )
            ).resolve(packageDirectory: app)

            do {
                _ = try resolution.environment(named: "production")
                XCTFail("Expected artifact incompatibility")
            } catch let error as SwiftWebLifecycleError {
                guard case .incompatibleArtifacts = error else {
                    XCTFail("Expected incompatibleArtifacts, got \(error)")
                    return
                }
            }
        }
    }

    func testResolverRejectsEnvironmentNamesThatCannotOwnGeneratedPaths() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let project = SwiftWebProjectManifest(
                schemaVersion: 3,
                application: .init(
                    product: "Calendar",
                    module: "Calendar",
                    type: "CalendarApp"
                ),
                environments: [
                    "../production": .init(
                        host: "cloud/worker",
                        deployment: "cloud/workers"
                    )
                ],
                defaults: .init(build: "../production", dev: nil, deploy: nil)
            )
            try writeJSON(project, to: app.appendingPathComponent("sweb.json"))

            do {
                _ = try await SwiftWebProjectResolver(
                    graphLoader: StaticDependencyGraphLoader(
                        graph: makeGraph(root: app, dependencies: [])
                    )
                ).resolve(packageDirectory: app)
                XCTFail("Expected invalid environment name")
            } catch let error as SwiftWebLifecycleError {
                guard case .invalidProjectEnvironmentName("../production") = error else {
                    XCTFail("Expected invalidProjectEnvironmentName, got \(error)")
                    return
                }
            }
        }
    }

    func testServiceTaskPathsResolveAgainstTheServiceWorkspaceExactlyOnce() {
        let task = SwiftWebLifecycleTask(
            id: "build",
            kind: .command,
            executable: "tool",
            workingDirectory: "{{service.workspace}}/cloudflare",
            inputs: [
                "{{project.root}}/Package.swift",
                "{{service.adapter.root}}/Adapter/sweb.json",
                "{{adapter.database.root}}/Package.swift",
                "wasm/Package.swift",
            ],
            outputs: ["cloudflare/src/database.wasm"]
        ).scoped(to: "database")

        XCTAssertEqual(
            task.workingDirectory,
            "{{services.database.workspace}}/cloudflare"
        )
        XCTAssertEqual(
            task.inputs,
            [
                "{{project.root}}/Package.swift",
                "{{services.database.adapter.root}}/Adapter/sweb.json",
                "{{adapter.database.root}}/Package.swift",
                "{{services.database.workspace}}/wasm/Package.swift",
            ]
        )
        XCTAssertEqual(
            task.outputs,
            ["{{services.database.workspace}}/cloudflare/src/database.wasm"]
        )
    }

    func testExecutionPlanRejectsPrimaryHostBuiltInKindsForServices() throws {
        let adapterPackage = SwiftPackageDependencyGraph.Package(
            identity: "adapter",
            name: "Adapter",
            url: "",
            version: "1.0.0",
            path: "/tmp/adapter",
            dependencies: []
        )
        let manifest = SwiftWebAdapterManifest(
            schemaVersion: 3,
            kind: "adapter",
            id: "adapter",
            defaults: .init(host: "host", deployment: "deployment"),
            hosts: ["host": .init(produces: ["page"])],
            deployments: [
                "deployment": .init(
                    accepts: ["page"],
                    acceptsServiceArtifacts: ["database"]
                )
            ],
            services: [
                "database": .init(
                    produces: ["database"],
                    operations: [
                        "build": [
                            .init(
                                id: "database.prepare",
                                kind: .prepareApplication
                            )
                        ]
                    ]
                )
            ]
        )
        let adapter = SwiftWebProjectResolution.Adapter(
            package: adapterPackage,
            directory: adapterPackage.directory,
            manifest: manifest
        )
        let service = SwiftWebProjectResolution.Service(
            name: "database",
            project: .init(
                application: .init(
                    product: "Database",
                    module: "Database",
                    type: "DatabaseApplication"
                ),
                adapter: "adapter/database"
            ),
            adapter: adapter,
            componentName: "database",
            component: try XCTUnwrap(manifest.services["database"])
        )
        let environment = SwiftWebProjectResolution.Environment(
            name: "production",
            project: .init(
                host: "adapter/host",
                deployment: "adapter/deployment",
                services: ["database"]
            ),
            hostAdapter: adapter,
            hostName: "host",
            host: try XCTUnwrap(manifest.hosts["host"]),
            deploymentAdapter: adapter,
            deploymentName: "deployment",
            deployment: try XCTUnwrap(manifest.deployments["deployment"]),
            services: [service]
        )

        XCTAssertThrowsError(
            try SwiftWebExecutionPlan.make(operation: .build, environment: environment)
        ) { error in
            guard let lifecycleError = error as? SwiftWebLifecycleError else {
                XCTFail("Expected SwiftWebLifecycleError, got \(error)")
                return
            }
            guard case SwiftWebLifecycleError.invalidTask(
                task: "database.prepare",
                reason: "service lifecycle tasks support only command kind"
            ) = lifecycleError else {
                XCTFail("Expected invalid service task kind, got \(error)")
                return
            }
        }
    }

    func testMaterializerComposesHostDeploymentAndApplicationOverlay() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let cloud = root.appendingPathComponent("cloud", isDirectory: true)
            try writeProjectManifest(
                at: app,
                host: "cloud/worker",
                deployment: "cloud/workers",
                overlays: [
                    .init(source: "Deployment", destination: "cloudflare")
                ]
            )
            try writeAdapterManifest(
                at: cloud,
                id: "cloud",
                host: "worker",
                produces: ["swiftweb.wasm-module"],
                deployment: "workers",
                accepts: ["swiftweb.wasm-module"],
                hostTemplates: [.init(source: "Adapter/Templates/Host", destination: "wasm")],
                deploymentTemplates: [
                    .init(source: "Adapter/Templates/Deployment", destination: "cloudflare")
                ]
            )
            try write(
                "{{application.type}}",
                to: cloud.appendingPathComponent("Adapter/Templates/Host/Launcher.swift")
            )
            try write(
                "name={{application.kebabName}}",
                to: cloud.appendingPathComponent("Adapter/Templates/Deployment/config.txt")
            )
            try write("project override", to: app.appendingPathComponent("Deployment/config.txt"))

            let resolution = try await SwiftWebProjectResolver(
                graphLoader: StaticDependencyGraphLoader(
                    graph: makeGraph(root: app, dependencies: [cloud])
                )
            ).resolve(packageDirectory: app)
            let environment = try resolution.environment(named: "production")
            let materialized = try SwiftWebEnvironmentMaterializer().materialize(
                resolution: resolution,
                environment: environment
            )

            XCTAssertEqual(
                try read(materialized.workspaceDirectory.appendingPathComponent("wasm/Launcher.swift")),
                "CalendarApp"
            )
            XCTAssertEqual(
                try read(materialized.workspaceDirectory.appendingPathComponent("cloudflare/config.txt")),
                "project override"
            )
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: materialized.rootDirectory.appendingPathComponent("plan.lock.json").path
                )
            )
            XCTAssertEqual(
                materialized.substitutions["adapter.cloud.swiftPackageRequirement"],
                "path: \"\(cloud.path)\""
            )
            XCTAssertEqual(
                materialized.substitutions["adapter.cloud.root"],
                cloud.path
            )
        }
    }

    func testMaterializerRemovesStaleManagedFilesAndPreservesBuildState() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let adapterDirectory = root.appendingPathComponent("adapter", isDirectory: true)
            try writeProjectManifest(
                at: app,
                host: "adapter/host",
                deployment: "adapter/deployment"
            )
            try writeAdapterManifest(
                at: adapterDirectory,
                id: "adapter",
                host: "host",
                produces: ["artifact"],
                deployment: "deployment",
                accepts: ["artifact"],
                hostTemplates: [.init(source: "Adapter/Templates", destination: "generated")]
            )
            let templateDirectory = adapterDirectory.appendingPathComponent("Adapter/Templates")
            let staleTemplate = templateDirectory.appendingPathComponent("stale.txt")
            try write("stale", to: staleTemplate)

            let resolver = SwiftWebProjectResolver(
                graphLoader: StaticDependencyGraphLoader(
                    graph: makeGraph(root: app, dependencies: [adapterDirectory])
                )
            )
            let resolution = try await resolver.resolve(packageDirectory: app)
            let environment = try resolution.environment(named: "production")
            let materializer = SwiftWebEnvironmentMaterializer()
            let first = try materializer.materialize(
                resolution: resolution,
                environment: environment
            )
            let buildState = first.workspaceDirectory.appendingPathComponent(
                "generated/node_modules/cache.bin"
            )
            try write("cache", to: buildState)

            try FileManager.default.removeItem(at: staleTemplate)
            try write("current", to: templateDirectory.appendingPathComponent("current.txt"))
            let second = try materializer.materialize(
                resolution: resolution,
                environment: environment
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: second.workspaceDirectory.appendingPathComponent("generated/stale.txt").path
                )
            )
            XCTAssertEqual(
                try read(second.workspaceDirectory.appendingPathComponent("generated/current.txt")),
                "current"
            )
            XCTAssertEqual(try read(buildState), "cache")
        }
    }

    func testResolverMaterializesSelectedServiceAndScopesItsLifecycleTasks() async throws {
        try await withTemporaryDirectory { root in
            let app = root.appendingPathComponent("App", isDirectory: true)
            let cloud = root.appendingPathComponent("cloud", isDirectory: true)
            let database = root.appendingPathComponent("database", isDirectory: true)
            let project = SwiftWebProjectManifest(
                schemaVersion: 3,
                application: .init(
                    product: "Calendar",
                    module: "Calendar",
                    type: "CalendarApp"
                ),
                services: [
                    "database": .init(
                        application: .init(
                            product: "CalendarDatabase",
                            module: "CalendarDatabase",
                            type: "CalendarDatabaseApplication"
                        ),
                        adapter: "database/cloudflare",
                        adapterTraits: ["GraphIndexes"],
                        actors: [
                            .init(
                                product: "CalendarActorContract",
                                module: "CalendarActorContract",
                                type: "CalendarDatabaseActor"
                            )
                        ],
                        variables: [
                            "cloudflare.bindingName": "DATABASE"
                        ],
                        operations: [
                            "build": [
                                .init(
                                    id: "calendar.prepare-database",
                                    kind: .command,
                                    stage: .beforeService
                                ),
                                .init(
                                    id: "calendar.verify-database",
                                    kind: .command,
                                    dependsOn: ["database.build"]
                                ),
                            ]
                        ]
                    )
                ],
                environments: [
                    "production": .init(
                        host: "cloud/worker",
                        deployment: "cloud/workers",
                        services: ["database"]
                    )
                ],
                defaults: .init(build: "production", dev: nil, deploy: "production")
            )
            try writeJSON(project, to: app.appendingPathComponent("sweb.json"))
            try writeJSON(
                SwiftWebAdapterManifest(
                    schemaVersion: 3,
                    kind: "adapter",
                    id: "cloud",
                    defaults: .init(host: "worker", deployment: "workers"),
                    hosts: [
                        "worker": .init(
                            produces: ["swiftweb.wasm"]
                        )
                    ],
                    deployments: [
                        "workers": .init(
                            accepts: ["swiftweb.wasm"],
                            acceptsServiceArtifacts: ["cloudflare.external-durable-object"],
                            actorBindings: [
                                "cloudflare.external-durable-object": .init(
                                    hostRoute: .init(
                                        transport: "swiftweb.http",
                                        endpointPrefix: "cloudflare-do://{{service.name}}/"
                                    ),
                                    configuration: [
                                        "bindingName": "{{service.cloudflare.bindingName}}"
                                    ]
                                )
                            ],
                            operations: [
                                "dev": [
                                    .init(
                                        id: "cloud.dev",
                                        kind: .command,
                                        lifetime: .persistent
                                    )
                                ]
                            ]
                        )
                    ]
                ),
                to: cloud.appendingPathComponent("Adapter/sweb.json")
            )
            try writeJSON(
                SwiftWebAdapterManifest(
                    schemaVersion: 3,
                    kind: "adapter",
                    id: "database",
                    defaults: .init(host: nil, deployment: nil),
                    hosts: [:],
                    deployments: [:],
                    services: [
                        "cloudflare": .init(
                            produces: ["cloudflare.external-durable-object"],
                            templates: [
                                .init(
                                    source: "Adapter/Templates/Service",
                                    destination: "runtime"
                                )
                            ],
                            operations: [
                                "build": [
                                    .init(id: "database.build", kind: .command)
                                ],
                                "dev": [
                                    .init(id: "database.prepare-dev", kind: .command),
                                    .init(
                                        id: "database.dev",
                                        kind: .command,
                                        lifetime: .persistent,
                                        dependsOn: ["database.prepare-dev"]
                                    ),
                                ],
                            ]
                        )
                    ]
                ),
                to: database.appendingPathComponent("Adapter/sweb.json")
            )
            try write(
                "{{service.application.type}}{{service.adapter.swiftPackageTraits}}",
                to: database.appendingPathComponent(
                    "Adapter/Templates/Service/Application.swift"
                )
            )

            let resolution = try await SwiftWebProjectResolver(
                graphLoader: StaticDependencyGraphLoader(
                    graph: makeGraph(root: app, dependencies: [cloud, database])
                )
            ).resolve(packageDirectory: app)
            let environment = try resolution.environment(named: "production")
            let materialized = try SwiftWebEnvironmentMaterializer().materialize(
                resolution: resolution,
                environment: environment
            )
            let plan = try SwiftWebExecutionPlan.make(
                operation: .build,
                environment: environment
            )

            XCTAssertEqual(environment.services.map(\.name), ["database"])
            XCTAssertEqual(
                try read(
                    materialized.workspaceDirectory.appendingPathComponent(
                        "services/database/runtime/Application.swift"
                    )
                ),
                "CalendarDatabaseApplication, traits: [\"GraphIndexes\"]"
            )
            XCTAssertEqual(
                plan.tasks.map(\.id),
                [
                    "service.database.calendar.prepare-database",
                    "service.database.database.build",
                    "service.database.calendar.verify-database",
                ]
            )
            XCTAssertEqual(
                plan.tasks.last?.dependsOn,
                ["service.database.database.build"]
            )
            XCTAssertEqual(
                materialized.substitutions["actors.swiftImports"],
                "import CalendarActorContract"
            )
            let actorBindings = try XCTUnwrap(
                materialized.substitutions["actors.swiftServiceBindings"]
            )
            XCTAssertTrue(
                actorBindings.contains(
                    "CalendarActorContract.CalendarDatabaseActor.actorTypeDescriptor.id"
                )
            )
            XCTAssertTrue(actorBindings.contains("cloudflare-do://database/"))
            XCTAssertTrue(actorBindings.contains("clientRoute: nil"))
            XCTAssertFalse(actorBindings.contains("production"))
            let deploymentBindings = try XCTUnwrap(
                materialized.substitutions["actors.deploymentBindingsJSON"]
            )
            XCTAssertTrue(deploymentBindings.contains("\"bindingName\":\"DATABASE\""))
            XCTAssertFalse(deploymentBindings.contains("swiftExpression"))
            let planLock = try read(
                materialized.rootDirectory.appendingPathComponent("plan.lock.json")
            )
            XCTAssertTrue(planLock.contains("\"schemaVersion\" : 3"))
            XCTAssertTrue(planLock.contains("\"type\" : \"CalendarDatabaseActor\""))

            let developmentPlan = try SwiftWebExecutionPlan.make(
                operation: .dev,
                environment: environment
            )
            XCTAssertEqual(
                developmentPlan.tasks.map(\.id),
                [
                    "service.database.database.prepare-dev",
                    "service.database.database.dev",
                    "cloud.dev",
                ]
            )
            XCTAssertEqual(
                developmentPlan.tasks.map(\.lifetime),
                [.finite, .persistent, .persistent]
            )
        }
    }

    func testExecutionPlanPreservesStagesAndHonorsDependencies() throws {
        let adapterPackage = SwiftPackageDependencyGraph.Package(
            identity: "adapter",
            name: "Adapter",
            url: "",
            version: "1.0.0",
            path: "/tmp/adapter",
            dependencies: []
        )
        let manifest = SwiftWebAdapterManifest(
            schemaVersion: 3,
            kind: "adapter",
            id: "adapter",
            defaults: .init(host: "host", deployment: "deployment"),
            hosts: [
                "host": .init(
                    produces: ["artifact"],
                    operations: ["build": [.init(id: "host", kind: .command)]]
                )
            ],
            deployments: [
                "deployment": .init(
                    accepts: ["artifact"],
                    operations: [
                        "build": [
                            .init(
                                id: "deployment",
                                kind: .command,
                                dependsOn: ["project"]
                            )
                        ]
                    ]
                )
            ]
        )
        let adapter = SwiftWebProjectResolution.Adapter(
            package: adapterPackage,
            directory: adapterPackage.directory,
            manifest: manifest
        )
        let environment = SwiftWebProjectResolution.Environment(
            name: "production",
            project: .init(
                host: "adapter/host",
                deployment: "adapter/deployment",
                operations: [
                    "build": [
                        .init(id: "before", kind: .command, stage: .beforeHost),
                        .init(id: "project", kind: .command, stage: .beforeDeployment, dependsOn: ["host"]),
                    ]
                ]
            ),
            hostAdapter: adapter,
            hostName: "host",
            host: try XCTUnwrap(manifest.hosts["host"]),
            deploymentAdapter: adapter,
            deploymentName: "deployment",
            deployment: try XCTUnwrap(manifest.deployments["deployment"]),
            services: []
        )

        let plan = try SwiftWebExecutionPlan.make(operation: .build, environment: environment)

        XCTAssertEqual(plan.tasks.map(\.id), ["before", "host", "project", "deployment"])
    }

    func testDevelopmentPlanStartsAllFiniteServiceTasksBeforePersistentTasks() throws {
        let adapterPackage = SwiftPackageDependencyGraph.Package(
            identity: "adapter",
            name: "Adapter",
            url: "",
            version: "1.0.0",
            path: "/tmp/adapter",
            dependencies: []
        )
        let manifest = SwiftWebAdapterManifest(
            schemaVersion: 3,
            kind: "adapter",
            id: "adapter",
            defaults: .init(host: "host", deployment: "deployment"),
            hosts: [
                "host": .init(produces: ["artifact"])
            ],
            deployments: [
                "deployment": .init(
                    accepts: ["artifact"],
                    acceptsServiceArtifacts: ["service"],
                    operations: [
                        "dev": [
                            .init(
                                id: "page.dev",
                                kind: .command,
                                lifetime: .persistent
                            )
                        ]
                    ]
                )
            ],
            services: [
                "worker": .init(
                    produces: ["service"],
                    operations: [
                        "dev": [
                            .init(id: "service.build", kind: .command),
                            .init(
                                id: "service.dev",
                                kind: .command,
                                lifetime: .persistent,
                                dependsOn: ["service.build"]
                            ),
                        ]
                    ]
                )
            ]
        )
        let adapter = SwiftWebProjectResolution.Adapter(
            package: adapterPackage,
            directory: adapterPackage.directory,
            manifest: manifest
        )
        let serviceComponent = try XCTUnwrap(manifest.services["worker"])
        let serviceApplication = SwiftWebProjectManifest.Application(
            product: "Service",
            module: "Service",
            type: "ServiceApplication"
        )
        let services = ["database", "search"].map { name in
            SwiftWebProjectResolution.Service(
                name: name,
                project: .init(
                    application: serviceApplication,
                    adapter: "adapter/worker"
                ),
                adapter: adapter,
                componentName: "worker",
                component: serviceComponent
            )
        }
        let environment = SwiftWebProjectResolution.Environment(
            name: "development",
            project: .init(
                host: "adapter/host",
                deployment: "adapter/deployment",
                services: services.map(\.name)
            ),
            hostAdapter: adapter,
            hostName: "host",
            host: try XCTUnwrap(manifest.hosts["host"]),
            deploymentAdapter: adapter,
            deploymentName: "deployment",
            deployment: try XCTUnwrap(manifest.deployments["deployment"]),
            services: services
        )

        let plan = try SwiftWebExecutionPlan.make(operation: .dev, environment: environment)

        XCTAssertEqual(
            plan.tasks.map(\.id),
            [
                "service.database.service.build",
                "service.search.service.build",
                "service.database.service.dev",
                "service.search.service.dev",
                "page.dev",
            ]
        )
        XCTAssertEqual(
            plan.tasks.map(\.lifetime),
            [.finite, .finite, .persistent, .persistent, .persistent]
        )
    }
}

private func waitForProcessIdentifier(in file: URL) async throws -> Int32 {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if let value = try? String(contentsOf: file, encoding: .utf8),
            let processIdentifier = Int32(value.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return processIdentifier
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    throw CocoaError(.fileReadNoSuchFile)
}

private func waitForProcessExit(_ processIdentifier: Int32) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while clock.now < deadline {
        if kill(processIdentifier, 0) != 0, errno == ESRCH {
            return true
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    return kill(processIdentifier, 0) != 0 && errno == ESRCH
}

private struct StaticDependencyGraphLoader: SwiftPackageDependencyGraphLoading {
    let graph: SwiftPackageDependencyGraph

    func load(packageDirectory: URL) async throws -> SwiftPackageDependencyGraph {
        graph
    }
}

private func makeGraph(root: URL, dependencies: [URL]) -> SwiftPackageDependencyGraph {
    SwiftPackageDependencyGraph(
        root: .init(
            identity: "app",
            name: "App",
            url: root.path,
            version: "unspecified",
            path: root.path,
            dependencies: dependencies.map { dependency in
                .init(
                    identity: dependency.lastPathComponent,
                    name: dependency.lastPathComponent,
                    url: dependency.path,
                    version: "unspecified",
                    path: dependency.path,
                    dependencies: []
                )
            }
        )
    )
}

private func writeProjectManifest(
    at directory: URL,
    host: String,
    deployment: String,
    overlays: [SwiftWebProjectManifest.Overlay] = []
) throws {
    let manifest = SwiftWebProjectManifest(
        schemaVersion: 3,
        application: .init(product: "Calendar", module: "Calendar", type: "CalendarApp"),
        environments: [
            "production": .init(host: host, deployment: deployment, overlays: overlays)
        ],
        defaults: .init(build: "production", dev: nil, deploy: "production")
    )
    try writeJSON(manifest, to: directory.appendingPathComponent("sweb.json"))
}

private func writeAdapterManifest(
    at directory: URL,
    id: String,
    host: String,
    produces: [String],
    deployment: String,
    accepts: [String],
    hostTemplates: [SwiftWebAdapterManifest.Template] = [],
    deploymentTemplates: [SwiftWebAdapterManifest.Template] = []
) throws {
    let manifest = SwiftWebAdapterManifest(
        schemaVersion: 3,
        kind: "adapter",
        id: id,
        defaults: .init(host: host, deployment: deployment),
        hosts: [host: .init(produces: produces, templates: hostTemplates)],
        deployments: [deployment: .init(accepts: accepts, templates: deploymentTemplates)]
    )
    try writeJSON(
        manifest,
        to: directory.appendingPathComponent("Adapter/sweb.json")
    )
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftweb-lifecycle-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            XCTFail("Failed to remove lifecycle test directory: \(error)")
        }
    }
    try body(directory)
}

private func withTemporaryDirectory(
    _ body: (URL) async throws -> Void
) async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftweb-lifecycle-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            XCTFail("Failed to remove lifecycle test directory: \(error)")
        }
    }
    try await body(directory)
}

private func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url)
}

private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
}

private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}
