@testable import ActorSystemGeneration
import Foundation
import Testing

@Suite
struct ActorSchemaGenerationTests {
    @Test
    func reconciliationStoresActorSourcePathsRelativeToTheDeclaredRoot() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func value() async throws -> Int { 1 }
            }
            """
        )
        defer { source.remove() }

        let schema = try reconcile(
            source: source.url,
            moduleName: "Fixture",
            packageIdentity: "fixture",
            sourceRoot: source.url.deletingLastPathComponent()
        )

        #expect(schema.actors.first?.sourcePath == "Fixture.swift")
    }

    @Test
    func generatorRejectsAnEmbeddedProfileWithoutAnEmbeddedTarget() throws {
        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceGenerator.generate(
                actors: [],
                portableTypes: [],
                schema: ActorSchemaLock(
                    packageIdentity: "fixture",
                    moduleName: "Fixture"
                ),
                toolchainFingerprint: "fixture-toolchain",
                profile: .embeddedClient,
                targetEnvironment: try generationEnvironment(for: .standardClient)
            )
        }
    }

    @Test
    func scannerRejectsConditionalDistributedActors() throws {
        let source = try TemporarySource(
            """
            #if canImport(Distributed)
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func value() async throws -> Int { 1 }
            }
            #endif
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsConditionalPortableValues() throws {
        let source = try TemporarySource(
            """
            #if os(macOS)
            struct Payload: Codable {
                var value: Int
            }
            #endif
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorPortableTypeScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerIncludesOnlyActiveConditionalImportsForProfile() throws {
        let source = try TemporarySource(
            """
            import Distributed
            #if hasFeature(Embedded)
            import EmbeddedActors
            #else
            import StandardActors
            #endif

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func value() async throws -> Int { 1 }
            }
            """
        )
        defer { source.remove() }

        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture",
            targetEnvironment: ActorGenerationTargetEnvironment(
                availableModules: ["EmbeddedActors", "StandardActors"],
                features: ["Embedded"],
                operatingSystem: "WASI",
                architecture: "wasm32",
                objectFormat: "wasm",
                pointerBitWidth: 32,
                languageVersion: [6],
                compilerVersion: [6, 4]
            )
        )

        #expect(actors.count == 1)
        #expect(actors[0].imports.contains("EmbeddedActors"))
        #expect(!actors[0].imports.contains("StandardActors"))
    }

    @Test
    func scannerCanSelectTheConcreteActorSystemWithoutConsumingLegacyActors() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = WebActorSystem

                distributed func current() async throws -> Int { 0 }
            }

            @LegacyActor
            distributed actor LegacyCounter: LegacyContract {
                typealias ActorSystem = LegacyWebActorSystem

                distributed func current() async throws -> Int { 0 }
            }
            """
        )
        defer { source.remove() }

        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture",
            includingActorSystemTypes: ["WebActorSystem"]
        )

        #expect(actors.map(\.symbol) == ["Fixture.Counter"])
    }

    @Test
    func scannerRejectsVariadicDistributedParameters() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func add(_ values: Int...) -> Int {
                    values.reduce(0, +)
                }
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsDistributedActorExtensions() throws {
        let source = try TemporarySource(
            """
            import Distributed
            import ServerOnlyKit

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func value() async throws -> Int {
                    1
                }
            }

            extension Counter {
                func helper() -> Int { 2 }
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsPortableValueExtensions() throws {
        let source = try TemporarySource(
            """
            struct Payload: Codable {
                var value: Int
            }

            extension Payload {
                var doubled: Int { value * 2 }
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorPortableTypeScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsCustomPortableStructConformances() throws {
        let source = try TemporarySource(
            """
            protocol ServerOnlyValue {}

            struct Payload: Codable, ServerOnlyValue {
                var value: Int
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorPortableTypeScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsNonportableStoredFieldDefaultExpressions() throws {
        let source = try TemporarySource(
            """
            import Foundation

            struct Payload: Codable {
                var token: String = UUID().uuidString
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorPortableTypeScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func scannerRejectsNonportableDistributedMethodDefaultExpressions() throws {
        let source = try TemporarySource(
            """
            import Distributed
            import Foundation

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func lookup(_ token: String = UUID().uuidString) -> String {
                    token
                }
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func standardClientPreservesSupportedDistributedMethodEffects() throws {
        let source = try TemporarySource(
            """
            import Distributed
            import ServerOnlyKit

            enum CounterError: Error, Codable {
                case rejected

                func serverOnlyDiagnostic() -> String {
                    "secret"
                }
            }

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func current(_ fallback: Int = 0) -> Int {
                    fallback
                }

                distributed func increment(by amount: Int) async throws -> Int {
                    amount
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let portableTypes = try ActorPortableTypeScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(
            source: source.url,
            existing: ActorSchemaLock(packageIdentity: "fixture")
        )
        let generated = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: portableTypes,
            schema: schema,
            toolchainFingerprint: "fixture-toolchain",
            profile: .standardClient,
            targetEnvironment: try generationEnvironment(for: .standardClient),
            distributedActorSystemTypeName: "SwiftWebActors.WebActorSystem"
        )
        let client = try #require(
            generated.first { $0.relativePath == "StandardClient/Counter.client.generated.swift" }
        )
        let values = try #require(
            generated.first { $0.relativePath == "ActorValues.generated.swift" }
        )

        #expect(client.contents.contains("distributed func current(_ fallback: Int = 0) -> Int"))
        #expect(client.contents.contains("distributed func increment(by amount: Int) async throws -> Int"))
        #expect(client.contents.contains("import SwiftWebActors"))
        #expect(client.contents.contains("public typealias ActorSystem = SwiftWebActors.WebActorSystem"))
        #expect(!client.contents.contains("import ServerOnlyKit"))
        #expect(values.contents.contains("enum CounterError: Codable, Error"))
        #expect(!values.contents.contains("import ServerOnlyKit"))
        #expect(!values.contents.contains("serverOnlyDiagnostic"))
        #expect(!values.contents.contains("secret"))
        let actor = try #require(actors.first)
        let methods = actor.methods
        #expect(methods.contains { $0.canonicalSignature.contains(":sync:nothrow") })
        #expect(methods.contains { $0.canonicalSignature.contains(":async:throws") })
    }

    @Test
    func standardClientGenerationRejectsTypedThrows() throws {
        let source = try TemporarySource(
            """
            import Distributed

            enum CounterError: Error, Codable {
                case rejected
            }

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func increment() async throws(CounterError) -> Int {
                    throw .rejected
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )

        expectTypedThrowsRejection(symbol: "Fixture.Counter.increment") {
            _ = try ActorSourceGenerator.generate(
                actors: actors,
                portableTypes: [],
                schema: ActorSchemaLock(
                    packageIdentity: "fixture",
                    moduleName: "Fixture"
                ),
                toolchainFingerprint: "fixture-toolchain",
                profile: .standardClient,
                targetEnvironment: try generationEnvironment(for: .standardClient)
            )
        }
    }

    @Test
    func removedFieldAndEnumCaseIDsStayReserved() throws {
        let firstSource = """
        import Distributed

        struct Payload: Codable {
            var oldValue: Int
        }

        enum Mode: Codable {
            case old(Int)
            case retained
        }

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            init(actorSystem: ActorSystem) {
                self.actorSystem = actorSystem
            }

            distributed func update(_ payload: Payload, mode: Mode) async throws -> Payload {
                payload
            }
        }
        """
        let secondSource = firstSource
            .replacingOccurrences(of: "oldValue", with: "newValue")
            .replacingOccurrences(of: "case old(Int)\n", with: "case added(String)\n")
        let temporary = try TemporarySource(firstSource)
        defer { temporary.remove() }

        let first = try reconcile(source: temporary.url, existing: .init(packageIdentity: "fixture"))
        try secondSource.write(to: temporary.url, atomically: true, encoding: .utf8)
        let second = try reconcile(source: temporary.url, existing: first)
        let firstPayload = try #require(first.valueTypes.first { $0.sourceType == "Payload" })
        let secondPayload = try #require(second.valueTypes.first { $0.sourceType == "Payload" })
        let firstField = try #require(firstPayload.fields.first)
        let secondField = try #require(secondPayload.fields.first)
        #expect(secondPayload.reservedFieldIDs.contains(firstField.fieldID))
        #expect(secondField.fieldID != firstField.fieldID)

        let firstMode = try #require(first.valueTypes.first { $0.sourceType == "Mode" })
        let secondMode = try #require(second.valueTypes.first { $0.sourceType == "Mode" })
        let removedCase = try #require(firstMode.cases.first { $0.sourceName == "old" })
        let addedCase = try #require(secondMode.cases.first { $0.sourceName == "added" })
        #expect(secondMode.reservedCaseIDs.contains(removedCase.caseID))
        #expect(addedCase.caseID != removedCase.caseID)
    }

    @Test
    func privateStoredCodableFieldFailsInsteadOfChangingWireShape() throws {
        let source = try TemporarySource(
            """
            struct Secret: Codable {
                private var token: String
            }
            """
        )
        defer { source.remove() }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorPortableTypeScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
        }
    }

    @Test
    func unsupportedTupleFailsBeforeSourceGeneration() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func update(_ value: (Int, Int)) async throws -> Int {
                    value.0 + value.1
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )

        #expect(throws: ActorGenerationError.self) {
            try ActorPortabilityValidator.validate(
                actors: actors,
                portableTypes: [],
                dependencySchemas: []
            )
        }
    }

    @Test
    func typedThrowsFailsBeforeSchemaReconciliation() throws {
        let source = try TemporarySource(
            """
            import Distributed

            enum CounterError: Error, Codable {
                case rejected
            }

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func increment() async throws(CounterError) -> Int {
                    throw .rejected
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )

        expectTypedThrowsRejection(symbol: "Fixture.Counter.increment") {
            try ActorPortabilityValidator.validate(
                actors: actors,
                portableTypes: [],
                dependencySchemas: []
            )
        }
        expectTypedThrowsRejection(symbol: "Fixture.Counter.increment") {
            _ = try ActorSchemaReconciler.reconcile(
                actors: actors,
                packageIdentity: "fixture",
                moduleName: "Fixture",
                toolchainFingerprint: "fixture-toolchain",
                compilerTargets: [],
                existing: ActorSchemaLock(
                    packageIdentity: "fixture",
                    moduleName: "Fixture"
                )
            )
        }
    }

    @Test
    func embeddedGenerationRejectsTypedThrows() throws {
        let source = try TemporarySource(
            """
            import Distributed

            enum CounterError: Error, Codable {
                case rejected(Int)
            }

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                init(actorSystem: ActorSystem) {
                    self.actorSystem = actorSystem
                }

                distributed func increment() async throws(CounterError) -> Int {
                    throw .rejected(1)
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        for profile in [ActorGenerationProfile.embeddedHost, .embeddedClient] {
            expectTypedThrowsRejection(symbol: "Fixture.Counter.increment") {
                _ = try ActorSourceGenerator.generate(
                    actors: actors,
                    portableTypes: [],
                    schema: ActorSchemaLock(
                        packageIdentity: "fixture",
                        moduleName: "Fixture"
                    ),
                    toolchainFingerprint: "fixture-toolchain",
                    profile: profile,
                    targetEnvironment: try generationEnvironment(for: profile)
                )
            }
        }
    }

    @Test
    func embeddedHostPreservesTheActorInterfaceAndInitializerSemantics() throws {
        let source = try TemporarySource(
            """
            import Distributed
            import SharedKit

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                private var value: Int = 1
                private let label: String

                init(initial: Int, actorSystem: ActorSystem) {
                    self.actorSystem = actorSystem
                    label = "counter"
                    value += initial
                }

                distributed func increment(by amount: Int) async throws -> Int {
                    value += amount
                    return value
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(source: source.url, existing: .init(packageIdentity: "fixture"))
        let generated = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: [],
            schema: schema,
            toolchainFingerprint: "fixture-toolchain",
            profile: .embeddedHost,
            targetEnvironment: try generationEnvironment(for: .embeddedHost)
        )
        let host = try #require(
            generated.first { $0.relativePath.contains("EmbeddedHost/Counter") }
        )

        #expect(host.contents.contains("import SharedKit"))
        #expect(host.contents.contains("public nonisolated final func whenLocal"))
        #expect(host.contents.contains("(isolated Counter)"))
        #expect(
            host.contents.contains(
                "internal nonisolated func increment(by amount: Int) async throws -> Int"
            )
        )
        #expect(host.contents.contains("private struct CounterEmbeddedState"))
        #expect(host.contents.contains("try actorSystem.resolve("))
        #expect(host.contents.contains("as: Counter.self"))
        #expect(!host.contents.contains("actorTypeID:"))
        #expect(host.contents.contains("guard case .none = state.label"))
        #expect(host.contents.contains("value += initial"))
        #expect(host.contents.contains("value += amount"))
        #expect(!host.contents.contains("CounterLocal"))
        #expect(
            host.contents.components(separatedBy: "self.actorSystem = actorSystem").count == 3
        )
    }

    @Test
    func embeddedHostRejectsStoredPropertyAttributes() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                @available(*, deprecated)
                private var value: Int = 0

                init(actorSystem: ActorSystem) {
                    self.actorSystem = actorSystem
                }

                distributed func current() async throws -> Int {
                    value
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(source: source.url, existing: .init(packageIdentity: "fixture"))

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSourceGenerator.generate(
                actors: actors,
                portableTypes: [],
                schema: schema,
                toolchainFingerprint: "fixture-toolchain",
                profile: .embeddedHost,
                targetEnvironment: try generationEnvironment(for: .embeddedHost)
            )
        }
    }

    @Test
    func embeddedHostRejectsFoundationBackedStoredTypesWhenFoundationIsUnavailable() throws {
        for typeName in ["Date", "UUID"] {
            let source = try TemporarySource(
                """
                import Distributed
                import Foundation

                distributed actor Counter {
                    typealias ActorSystem = TestActorSystem

                    private var value: \(typeName) = \(typeName)()

                    init(actorSystem: ActorSystem) {
                        self.actorSystem = actorSystem
                    }

                    distributed func current() async throws -> Int {
                        0
                    }
                }
                """
            )
            defer { source.remove() }
            let actors = try ActorSourceScanner.scan(
                sourceFiles: [source.url],
                moduleName: "Fixture"
            )
            let schema = try reconcile(
                source: source.url,
                existing: .init(packageIdentity: "fixture")
            )

            do {
                _ = try ActorSourceGenerator.generate(
                    actors: actors,
                    portableTypes: [],
                    schema: schema,
                    toolchainFingerprint: "fixture-toolchain",
                    profile: .embeddedHost,
                    targetEnvironment: try generationEnvironment(for: .embeddedHost)
                )
                Issue.record("Expected unavailable Foundation import rejection for \(typeName)")
            } catch ActorGenerationError.unsupportedDeclaration(let symbol, let reason) {
                #expect(symbol == "Fixture.Counter")
                #expect(reason.contains("unavailable modules: Foundation"))
            } catch {
                Issue.record("Unexpected Embedded host portability error: \(error)")
            }
        }
    }

    @Test
    func embeddedHostRejectsNestedCodableActorMembers() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                struct Snapshot: Codable {
                    let value: Int
                }

                init(actorSystem: ActorSystem) {
                    self.actorSystem = actorSystem
                }

                distributed func current() async throws -> Int {
                    0
                }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(source: source.url, existing: .init(packageIdentity: "fixture"))

        do {
            _ = try ActorSourceGenerator.generate(
                actors: actors,
                portableTypes: [],
                schema: schema,
                toolchainFingerprint: "fixture-toolchain",
                profile: .embeddedHost,
                targetEnvironment: try generationEnvironment(for: .embeddedHost)
            )
            Issue.record("Expected nested Codable conformance rejection")
        } catch ActorGenerationError.unsupportedDeclaration(let symbol, let reason) {
            #expect(symbol == "Fixture.Counter.Snapshot")
            #expect(reason.contains("cannot retain Codable, Encodable, or Decodable"))
        } catch {
            Issue.record("Unexpected Embedded host portability error: \(error)")
        }
    }

    @Test
    func ambiguousDependencyValueTypeFailsSchemaReconciliation() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func accept(_ payload: Payload) async throws {}
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let mapping = try #require(actors.first?.methods.first).canonicalSignature
        let dependencies = ["First.Payload", "Second.Payload"].enumerated().map { index, name in
            ActorSchemaLockValueType(
                sourceType: name,
                typeID: ActorSchemaLockID128(high: 0, low: UInt64(index + 1)),
                fields: [],
                cases: [],
                reservedFieldIDs: [],
                reservedCaseIDs: []
            )
        }

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSchemaReconciler.reconcile(
                actors: actors,
                packageIdentity: "fixture",
                toolchainFingerprint: "fixture-toolchain",
                compilerTargets: [
                    ActorCompilerTargetMapping(
                        key: ActorCompilerTargetKey(
                            actorSymbol: "Fixture.Counter",
                            canonicalMethodSignature: mapping
                        ),
                        targetIdentifier: "target"
                    ),
                ],
                dependencyValueTypes: dependencies,
                existing: ActorSchemaLock(packageIdentity: "fixture")
            )
        }
    }

    @Test
    func actorFingerprintChangesOnlyForWireBreakingValueEvolution() throws {
        let firstSource = """
        import Distributed

        struct Payload: Codable {
            var value: Int
        }

        distributed actor Counter {
            typealias ActorSystem = TestActorSystem

            distributed func read(_ payload: Payload) async throws -> Payload {
                payload
            }
        }
        """
        let compatibleSource = firstSource
            .replacingOccurrences(of: "var value: Int", with: "var value: Int\n    var note: String?")
            .replacingOccurrences(
                of: "\n        distributed func read",
                with: "\n        distributed func reset() async throws {}\n\n        distributed func read"
            )
        let breakingSource = compatibleSource.replacingOccurrences(
            of: "var value: Int",
            with: "var value: String"
        )
        let temporary = try TemporarySource(firstSource)
        defer { temporary.remove() }

        let first = try reconcile(
            source: temporary.url,
            existing: ActorSchemaLock(packageIdentity: "fixture")
        )
        try compatibleSource.write(to: temporary.url, atomically: true, encoding: .utf8)
        let compatible = try reconcile(source: temporary.url, existing: first)
        try breakingSource.write(to: temporary.url, atomically: true, encoding: .utf8)
        let breaking = try reconcile(source: temporary.url, existing: compatible)

        let firstFingerprint = try #require(first.actors.first).schemaFingerprint
        let compatibleFingerprint = try #require(compatible.actors.first).schemaFingerprint
        let breakingFingerprint = try #require(breaking.actors.first).schemaFingerprint
        #expect(compatibleFingerprint == firstFingerprint)
        #expect(breakingFingerprint != compatibleFingerprint)
    }

    @Test
    func explicitSchemaMovesRetainAuthoritativeIDs() throws {
        let source = try TemporarySource(
            """
            import Distributed

            struct Payload: Codable {
                var oldValue: Int
            }

            enum Mode: Codable {
                case old
            }

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                private var oldState: Int = 0

                distributed func update(_ payload: Payload, mode: Mode) async throws -> Payload {
                    payload
                }
            }
            """
        )
        defer { source.remove() }
        let initial = try reconcile(
            source: source.url,
            existing: ActorSchemaLock(packageIdentity: "fixture")
        )
        let payload = try #require(initial.valueTypes.first { $0.sourceType == "Payload" })
        let mode = try #require(initial.valueTypes.first { $0.sourceType == "Mode" })
        let actor = try #require(initial.actors.first)
        let payloadFieldID = try #require(payload.fields.first).fieldID
        let modeCaseID = try #require(mode.cases.first).caseID
        let actorFieldID = try #require(actor.fields.first).fieldID
        let actorTypeID = actor.typeID

        var moved = try ActorSchemaReconciler.moveValueField(
            in: initial,
            valueType: "Payload",
            from: "oldValue",
            to: "newValue"
        )
        moved = try ActorSchemaReconciler.moveEnumCase(
            in: moved,
            valueType: "Mode",
            from: "old",
            to: "new"
        )
        moved = try ActorSchemaReconciler.moveActorField(
            in: moved,
            actorSymbol: "Fixture.Counter",
            from: "oldState",
            to: "newState"
        )
        moved = try ActorSchemaReconciler.moveValueType(
            in: moved,
            from: "Payload",
            to: "Message"
        )
        moved = try ActorSchemaReconciler.moveActor(
            in: moved,
            from: "Fixture.Counter",
            to: "Fixture.RenamedCounter"
        )

        let movedPayload = try #require(moved.valueTypes.first { $0.sourceType == "Message" })
        let movedMode = try #require(moved.valueTypes.first { $0.sourceType == "Mode" })
        let movedActor = try #require(moved.actors.first)
        #expect(movedPayload.typeID == payload.typeID)
        #expect(movedPayload.canonicalType == "Fixture.Message")
        #expect(try #require(movedPayload.fields.first).fieldID == payloadFieldID)
        #expect(try #require(movedMode.cases.first).caseID == modeCaseID)
        #expect(try #require(movedActor.fields.first).fieldID == actorFieldID)
        #expect(movedActor.typeID == actorTypeID)
        #expect(movedActor.sourceSymbol == "Fixture.RenamedCounter")
        #expect(movedActor.moduleName == "Fixture")
        #expect(throws: ActorGenerationError.self) {
            _ = try ActorSchemaReconciler.moveActor(
                in: moved,
                from: "Fixture.RenamedCounter",
                to: "RenamedFeature.Counter"
            )
        }
    }

    @Test
    func generatedActorExportsSchemaMetadataAndModuleSpecificBootstrap() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func current() async throws -> Int { 0 }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(
            source: source.url,
            existing: ActorSchemaLock(packageIdentity: "fixture")
        )
        let generated = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: [],
            schema: schema,
            toolchainFingerprint: "fixture-toolchain",
            profile: .nativeHost,
            targetEnvironment: try generationEnvironment(for: .nativeHost)
        )
        let descriptors = try #require(
            generated.first { $0.relativePath == "ActorSchema.generated.swift" }
        )
        let bootstrap = try #require(
            generated.first { $0.relativePath == "Native/ActorRegistrations.generated.swift" }
        )

        #expect(descriptors.contents.contains("extension Counter: ActorSystemReference"))
        #expect(descriptors.contents.contains("public nonisolated static var actorTypeDescriptor"))
        #expect(descriptors.contents.contains("public enum FixtureActorSchemaModule"))
        #expect(
            bootstrap.contents.contains(
                "public enum FixtureActorSystemBootstrap: SwiftActorSystemBootstrap"
            )
        )
        #expect(bootstrap.contents.contains("try actorSystem.registerCodec"))
        #expect(
            bootstrap.contents.contains(
                "extension Counter: SwiftActorSystemBootstrapProvider"
            )
        )
        #expect(
            bootstrap.contents.contains(
                "actorSystemBootstrap: any SwiftActorSystemBootstrap.Type"
            )
        )
    }

    @Test
    func portableBuiltinTypeIdentityIsStableAcrossPackages() throws {
        let source = try TemporarySource(
            """
            import Distributed

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func current() async throws -> Int { 0 }
            }
            """
        )
        defer { source.remove() }

        let first = try reconcile(
            source: source.url,
            moduleName: "FirstModule",
            packageIdentity: "first-package"
        )
        let second = try reconcile(
            source: source.url,
            moduleName: "SecondModule",
            packageIdentity: "second-package"
        )
        let firstInt = try #require(
            first.valueTypes.first { $0.canonicalType == "Swift.Int" }
        )
        let secondInt = try #require(
            second.valueTypes.first { $0.canonicalType == "Swift.Int" }
        )

        #expect(firstInt.typeID == secondInt.typeID)
    }

    @Test
    func generatedBootstrapDeclaresDependencyBootstraps() throws {
        let source = try TemporarySource(
            """
            import Distributed
            import SharedActors

            distributed actor Counter {
                typealias ActorSystem = TestActorSystem

                distributed func current() async throws -> Int { 0 }
            }
            """
        )
        defer { source.remove() }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source.url],
            moduleName: "Fixture"
        )
        let schema = try reconcile(source: source.url, existing: .init(packageIdentity: "fixture"))
        let dependency = ActorSchemaLock(
            packageIdentity: "shared-actors",
            moduleName: "SharedActors"
        )

        let generated = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: [],
            schema: schema,
            toolchainFingerprint: "fixture-toolchain",
            profile: .nativeHost,
            targetEnvironment: try generationEnvironment(for: .nativeHost),
            dependencySchemas: [dependency]
        )
        let bootstrap = try #require(
            generated.first { $0.relativePath == "Native/ActorRegistrations.generated.swift" }
        )

        #expect(bootstrap.contents.contains("import SharedActors"))
        #expect(
            bootstrap.contents.contains(
                "SharedActors.SharedActorsActorSystemBootstrap.self"
            )
        )
        #expect(bootstrap.contents.contains("public static let bootstrapIdentifier = \"fixture:Fixture\""))
    }

    @Test
    func dependencyValidationAllowsMultipleModulesFromOnePackage() throws {
        try ActorSystemCompiler.validateDependencySchemas([
            ActorSchemaLock(
                packageIdentity: "shared-actors",
                moduleName: "SharedActorsCore"
            ),
            ActorSchemaLock(
                packageIdentity: "shared-actors",
                moduleName: "SharedActorsFeature"
            ),
        ])
    }

    @Test
    func dependencyValidationRejectsDuplicateModuleNames() {
        #expect(throws: ActorGenerationError.self) {
            try ActorSystemCompiler.validateDependencySchemas([
                ActorSchemaLock(
                    packageIdentity: "first-package",
                    moduleName: "SharedActors"
                ),
                ActorSchemaLock(
                    packageIdentity: "second-package",
                    moduleName: "SharedActors"
                ),
            ])
        }
    }

    private func reconcile(
        source: URL,
        existing: ActorSchemaLock
    ) throws -> ActorSchemaLock {
        try reconcile(
            source: source,
            moduleName: "Fixture",
            packageIdentity: "fixture",
            existing: existing
        )
    }

    private func reconcile(
        source: URL,
        moduleName: String,
        packageIdentity: String,
        sourceRoot: URL? = nil,
        existing: ActorSchemaLock? = nil
    ) throws -> ActorSchemaLock {
        let actors = try ActorSourceScanner.scan(
            sourceFiles: [source],
            moduleName: moduleName
        )
        let portableTypes = try ActorPortableTypeScanner.scan(
            sourceFiles: [source],
            moduleName: moduleName
        )
        let mappings = actors.flatMap { actor in
            actor.methods.map { method in
                ActorCompilerTargetMapping(
                    key: ActorCompilerTargetKey(
                        actorSymbol: actor.symbol,
                        canonicalMethodSignature: method.canonicalSignature
                    ),
                    targetIdentifier: "target:\(actor.symbol):\(method.canonicalSignature)"
                )
            }
        }
        return try ActorSchemaReconciler.reconcile(
            actors: actors,
            packageIdentity: packageIdentity,
            moduleName: moduleName,
            toolchainFingerprint: "fixture-toolchain",
            compilerTargets: mappings,
            portableTypes: portableTypes,
            sourceRoot: sourceRoot,
            existing: existing ?? ActorSchemaLock(
                packageIdentity: packageIdentity,
                moduleName: moduleName
            )
        )
    }

    private func expectTypedThrowsRejection(
        symbol expectedSymbol: String,
        _ operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected the portable actor contract to reject typed throws")
        } catch ActorGenerationError.unsupportedDeclaration(let symbol, let reason) {
            #expect(symbol == expectedSymbol)
            #expect(reason == ActorMethodEffectValidator.typedThrowsReason)
        } catch {
            Issue.record("Unexpected typed throws validation error: \(error)")
        }
    }

    private func generationEnvironment(
        for profile: ActorGenerationProfile
    ) throws -> ActorGenerationTargetEnvironment {
        let isEmbedded = profile == .embeddedHost || profile == .embeddedClient
        return try ActorGenerationTargetEnvironment(
            availableModules: [
                "ActorSystemCore", "ActorSystemDistributed", "ActorSystemEmbedded",
                "Distributed", "SharedActors", "SharedKit", "Swift", "SwiftWebActors",
            ],
            features: isEmbedded ? ["Embedded"] : [],
            operatingSystem: isEmbedded ? "WASI" : "macOS",
            architecture: isEmbedded ? "wasm32" : "arm64",
            objectFormat: isEmbedded ? "wasm" : "macho",
            pointerBitWidth: isEmbedded ? 32 : 64,
            atomicBitWidths: [8, 16, 32, 64],
            languageVersion: [6],
            compilerVersion: [6, 4]
        )
    }
}

private struct TemporarySource {
    let directory: URL
    let url: URL

    init(_ contents: String) throws {
        self.directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "actor-schema-test-\(UUID().uuidString)",
            isDirectory: true
        )
        self.url = directory.appendingPathComponent("Fixture.swift")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            // Test cleanup does not change the assertion result.
        }
    }
}
