@testable import ActorSystemGeneration
import Foundation
import Testing

@Suite
struct ActorSourceProjectorTests {
    @Test
    func embeddedProjectionDropsInactiveConditionalUnsupportedImports() throws {
        let source = """
        #if canImport(Distributed)
        import Distributed
        #else
        import ActorSystemEmbedded
        #endif

        struct ClientHelper {}
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Conditional.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedClient,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedClient,
                modules: ["ActorSystemEmbedded"]
            )
        )

        #expect(!projected.contains("Distributed"))
        #expect(projected.contains("import ActorSystemEmbedded"))
        #expect(projected.contains("struct ClientHelper"))
        #expect(!projected.contains("#if"))
    }

    @Test
    func embeddedProjectionRejectsAnActiveUnavailableConditionalImport() throws {
        let source = """
        #if hasFeature(Embedded)
        import Foundation
        #endif

        struct ClientHelper {}
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Conditional.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceProjector.project(
                source: source,
                input: input,
                profile: .embeddedClient,
                targetEnvironment: try targetEnvironment(
                    profile: .embeddedClient,
                    modules: ["ActorSystemEmbedded"]
                )
            )
        }
    }

    @Test
    func embeddedProjectionRetainsAnAvailableFoundationImport() throws {
        let source = """
        import Foundation

        struct BoardDate {
            let value: Date
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "BoardDate.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedHost,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedHost,
                modules: ["ActorSystemEmbedded", "Foundation"]
            )
        )

        #expect(projected.contains("import Foundation"))
        #expect(projected.contains("let value: Date"))
    }

    @Test
    func embeddedProjectionRejectsRetainedCodableDeclarations() throws {
        let source = """
        struct RetainedPayload: Codable {
            let value: Int
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "RetainedPayload.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceProjector.project(
                source: source,
                input: input,
                profile: .embeddedClient,
                targetEnvironment: try targetEnvironment(
                    profile: .embeddedClient,
                    modules: ["ActorSystemEmbedded"]
                )
            )
        }
    }

    @Test
    func projectionUsesExplicitCustomConditionContract() throws {
        let source = """
        #if APPLICATION_CUSTOM_FLAG
        import ClientExtension
        #endif
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Conditional.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .standardClient,
            targetEnvironment: try targetEnvironment(
                profile: .standardClient,
                modules: ["ClientExtension"],
                customConditions: ["APPLICATION_CUSTOM_FLAG"]
            )
        )
        #expect(projected.contains("import ClientExtension"))
    }

    @Test
    func embeddedHostUsesTheExplicitTargetDescription() throws {
        let source = """
        #if arch(arm64)
        struct BoardHelper {}
        #endif
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "BoardHelper.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedHost,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedHost,
                modules: ["ActorSystemEmbedded"],
                architecture: "arm64"
            )
        )
        #expect(projected.contains("struct BoardHelper"))
    }

    @Test
    func embeddedProjectionReplacesOnlyGeneratedDeclarations() throws {
        let source = """
        import Distributed
        import SharedKit

        struct Payload: Codable {
            var value: Int
        }

        struct Unrelated {
            var name: String
        }

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func update(_ payload: Payload) async throws -> Payload {
                payload
            }
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Feature.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: ["Counter"],
            replacedPortableTypeNames: ["Payload"]
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedClient,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedClient,
                modules: ["SharedKit"]
            )
        )

        #expect(!projected.contains("import Distributed"))
        #expect(projected.contains("import SharedKit"))
        #expect(!projected.contains("struct Payload"))
        #expect(!projected.contains("distributed actor Counter"))
        #expect(projected.contains("struct Unrelated"))
    }

    @Test
    func standardProjectionReplacesPortableValuesAndRetainsProfileImports() throws {
        let source = """
        import Distributed

        struct Payload: Codable {
            var value: Int
        }

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func update(_ payload: Payload) async throws -> Payload {
                payload
            }
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Feature.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: ["Counter"],
            replacedPortableTypeNames: ["Payload"]
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .standardClient,
            targetEnvironment: try targetEnvironment(
                profile: .standardClient,
                modules: ["Distributed"]
            )
        )

        #expect(projected.contains("import Distributed"))
        #expect(!projected.contains("struct Payload"))
        #expect(!projected.contains("distributed actor Counter"))
    }

    @Test
    func clientProjectionRemovesExtensionsOfReplacedActor() throws {
        let source = """
        import Distributed

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func value() async throws -> Int {
                1
            }
        }

        extension Counter {
            func serverOnlyHelper() -> String {
                "secret"
            }
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Feature.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: ["Counter"],
            replacedPortableTypeNames: []
        )

        let client = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedClient,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedClient,
                modules: []
            )
        )
        let host = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .embeddedHost,
            targetEnvironment: try targetEnvironment(
                profile: .embeddedHost,
                modules: []
            )
        )

        #expect(!client.contains("serverOnlyHelper"))
        #expect(host.contains("serverOnlyHelper"))
    }

    @Test
    func projectionRejectsSourceChangedAfterGeneration() throws {
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Feature.swift",
            contentDigest: ActorStableHash.digest("struct Value {}"),
            replacedActorNames: [],
            replacedPortableTypeNames: []
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceProjector.project(
                source: "struct Changed {}",
                input: input,
                profile: .embeddedClient,
                targetEnvironment: try targetEnvironment(
                    profile: .embeddedClient,
                    modules: []
                )
            )
        }
    }

    @Test
    func strictClientProjectionDropsImportsWhenTheWholeFileIsReplaced() throws {
        let source = """
        import Distributed
        import ServerOnlyKit

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func value() async throws -> Int { 1 }
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Counter.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: ["Counter"],
            replacedPortableTypeNames: []
        )

        let projected = try ActorSourceProjector.project(
            source: source,
            input: input,
            profile: .standardClient,
            targetEnvironment: try targetEnvironment(
                profile: .standardClient,
                modules: ["Distributed"]
            )
        )

        #expect(projected.contains("import Distributed"))
        #expect(!projected.contains("ServerOnlyKit"))
        #expect(!projected.contains("actor Counter"))
    }

    @Test
    func strictClientProjectionRejectsUnavailableImportsBesideRetainedDeclarations() throws {
        let source = """
        import ServerOnlyKit

        struct RetainedValue {
            let value: ServerValue
        }

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func value() async throws -> Int { 1 }
        }
        """
        let input = ActorGeneratedManifest.InputSource(
            relativePath: "Mixed.swift",
            contentDigest: ActorStableHash.digest(source),
            replacedActorNames: ["Counter"],
            replacedPortableTypeNames: []
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceProjector.project(
                source: source,
                input: input,
                profile: .standardClient,
                targetEnvironment: try targetEnvironment(
                    profile: .standardClient,
                    modules: ["Distributed"]
                )
            )
        }
    }

    private func targetEnvironment(
        profile: ActorGenerationProfile,
        modules: Set<String>,
        customConditions: Set<String> = [],
        architecture: String = "wasm32"
    ) throws -> ActorGenerationTargetEnvironment {
        try ActorGenerationTargetEnvironment(
            availableModules: modules,
            customConditions: customConditions,
            features: profile == .embeddedClient || profile == .embeddedHost
                ? ["Embedded"]
                : [],
            operatingSystem: architecture == "wasm32" ? "WASI" : "none",
            architecture: architecture,
            runtimes: ["_Native"],
            objectFormat: architecture == "wasm32" ? "wasm" : "elf",
            pointerBitWidth: architecture == "wasm32" ? 32 : 64,
            atomicBitWidths: [8, 16, 32, 64],
            languageVersion: [6],
            compilerVersion: [6, 4]
        )
    }
}
