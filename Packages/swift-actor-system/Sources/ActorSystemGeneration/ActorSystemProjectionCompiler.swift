import Foundation

public struct ActorSystemProjectionRequest: Sendable {
    public let sourceFiles: [URL]
    public let sourceRoot: URL?
    public let moduleName: String
    public let packageIdentity: String
    public let profile: ActorGenerationProfile
    public let schemaLockURL: URL
    public let outputDirectory: URL
    public let toolchainFingerprint: String
    public let expectedToolchainFingerprint: String?
    public let dependencySchemas: [ActorSchemaLock]
    public let distributedActorSystemTypeName: String
    public let includedActorSystemTypeNames: Set<String>?
    public let includedActorSymbols: Set<String>?
    public let targetEnvironment: ActorGenerationTargetEnvironment

    public init(
        sourceFiles: [URL],
        sourceRoot: URL? = nil,
        moduleName: String,
        packageIdentity: String,
        profile: ActorGenerationProfile,
        schemaLockURL: URL,
        outputDirectory: URL,
        toolchainFingerprint: String,
        expectedToolchainFingerprint: String? = nil,
        dependencySchemas: [ActorSchemaLock] = [],
        distributedActorSystemTypeName: String = "SwiftActorSystem",
        includedActorSystemTypeNames: Set<String>? = nil,
        includedActorSymbols: Set<String>? = nil,
        targetEnvironment: ActorGenerationTargetEnvironment
    ) {
        self.sourceFiles = sourceFiles
        self.sourceRoot = sourceRoot
        self.moduleName = moduleName
        self.packageIdentity = packageIdentity
        self.profile = profile
        self.schemaLockURL = schemaLockURL
        self.outputDirectory = outputDirectory
        self.toolchainFingerprint = toolchainFingerprint
        self.expectedToolchainFingerprint = expectedToolchainFingerprint
        self.dependencySchemas = dependencySchemas
        self.distributedActorSystemTypeName = distributedActorSystemTypeName
        self.includedActorSystemTypeNames = includedActorSystemTypeNames
        self.includedActorSymbols = includedActorSymbols
        self.targetEnvironment = targetEnvironment
    }
}

extension ActorSystemProjectionRequest: ActorSystemManifestRequest {}

public extension ActorSystemCompiler {
    static func project(
        _ request: ActorSystemProjectionRequest
    ) throws -> ActorSystemCompilationResult {
        try validateDependencySchemas(request.dependencySchemas)
        guard FileManager.default.fileExists(atPath: request.schemaLockURL.path) else {
            throw ActorGenerationError.schemaConflict(
                reason: "ActorSchema.lock is required before profile projection"
            )
        }
        let toolchainFingerprint = request.toolchainFingerprint
        guard !toolchainFingerprint.isEmpty else {
            throw ActorGenerationError.schemaConflict(
                reason: "The build integration supplied an empty toolchain fingerprint"
            )
        }
        if let expected = request.expectedToolchainFingerprint,
           expected != toolchainFingerprint {
            throw ActorGenerationError.schemaConflict(
                reason: "Compiler fingerprint \(toolchainFingerprint) does not match expected \(expected)"
            )
        }
        let actors = try ActorSourceScanner.scan(
            sourceFiles: request.sourceFiles,
            moduleName: request.moduleName,
            includingActorSystemTypes: request.includedActorSystemTypeNames,
            includingActorSymbols: request.includedActorSymbols,
            targetEnvironment: request.targetEnvironment
        )
        try ActorMethodEffectValidator.validatePortableActorContract(actors)
        let rootValueTypes = Set(actors.flatMap { actor in
            actor.methods.flatMap { method in
                method.parameters.map(\.type)
                    + (isVoidProjectionType(method.returnType) ? [] : [method.returnType])
                    + (typedProjectionErrorType(method.throwsClause).map { [$0] } ?? [])
            }
        })
        let portableTypes = try ActorPortableTypeScanner.scan(
            sourceFiles: request.sourceFiles,
            moduleName: request.moduleName,
            reachableFrom: rootValueTypes,
            targetEnvironment: request.targetEnvironment
        )
        try ActorPortabilityValidator.validate(
            actors: actors,
            portableTypes: portableTypes,
            dependencySchemas: request.dependencySchemas
        )
        let existing = try ActorSchemaLockStore.load(
            from: request.schemaLockURL,
            packageIdentity: request.packageIdentity,
            moduleName: request.moduleName
        )
        let mappings = try lockedCompilerMappings(
            actors: actors,
            schema: existing,
            toolchainFingerprint: toolchainFingerprint
        )
        let reconciled = try ActorSchemaReconciler.reconcile(
            actors: actors,
            packageIdentity: request.packageIdentity,
            moduleName: request.moduleName,
            toolchainFingerprint: toolchainFingerprint,
            compilerTargets: mappings,
            portableTypes: portableTypes,
            dependencyValueTypes: request.dependencySchemas.flatMap(\.valueTypes),
            sourceRoot: request.sourceRoot,
            existing: existing
        )
        guard reconciled == existing else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor sources changed; run authoritative actor-system generation and commit ActorSchema.lock"
            )
        }
        var sources = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: portableTypes,
            schema: existing,
            toolchainFingerprint: toolchainFingerprint,
            profile: request.profile,
            targetEnvironment: request.targetEnvironment,
            dependencySchemas: request.dependencySchemas,
            distributedActorSystemTypeName: request.distributedActorSystemTypeName
        )
        let manifest = try makeManifest(
            request: request,
            actors: actors,
            portableTypes: portableTypes,
            schema: existing,
            toolchainFingerprint: toolchainFingerprint,
            generatedSources: sources
        )
        sources.append(
            GeneratedActorSource(
                relativePath: "ActorGeneratedManifest.json",
                contents: String(decoding: try manifest.encodedData(), as: UTF8.self)
            )
        )
        let generatedFiles = try ActorGeneratedSourceWriter.write(
            sources,
            to: request.outputDirectory
        )
        return ActorSystemCompilationResult(
            schema: existing,
            manifest: manifest,
            generatedFiles: generatedFiles
        )
    }

    private static func lockedCompilerMappings(
        actors: [ActorSourceModel],
        schema: ActorSchemaLock,
        toolchainFingerprint: String
    ) throws -> [ActorCompilerTargetMapping] {
        var mappings: [ActorCompilerTargetMapping] = []
        for actor in actors {
            guard let lockedActor = schema.actors.first(where: {
                $0.sourceSymbol == actor.symbol
            }) else {
                throw ActorGenerationError.missingSchemaEntry(symbol: actor.symbol)
            }
            for method in actor.methods {
                guard let lockedMethod = lockedActor.methods.first(where: {
                    $0.canonicalSignature == method.canonicalSignature
                }),
                let alias = lockedMethod.compilerTargetAliases.first(where: {
                    $0.toolchainFingerprint == toolchainFingerprint
                })
                else {
                    throw ActorGenerationError.missingCompilerTarget(
                        symbol: actor.symbol,
                        method: method.canonicalSignature
                    )
                }
                mappings.append(
                    ActorCompilerTargetMapping(
                        key: ActorCompilerTargetKey(
                            actorSymbol: actor.symbol,
                            canonicalMethodSignature: method.canonicalSignature
                        ),
                        targetIdentifier: alias.targetIdentifier
                    )
                )
            }
        }
        return mappings
    }

    private static func typedProjectionErrorType(_ throwsClause: String?) -> String? {
        guard let throwsClause,
              let open = throwsClause.firstIndex(of: "("),
              let close = throwsClause.lastIndex(of: ")"),
              open < close
        else {
            return nil
        }
        return String(throwsClause[throwsClause.index(after: open)..<close])
    }

    private static func isVoidProjectionType(_ type: String) -> Bool {
        type == "Void" || type == "()" || type == "Swift.Void"
    }
}
