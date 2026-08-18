import Foundation

protocol ActorSystemManifestRequest {
    var sourceFiles: [URL] { get }
    var sourceRoot: URL? { get }
    var moduleName: String { get }
    var packageIdentity: String { get }
    var profile: ActorGenerationProfile { get }
    var dependencySchemas: [ActorSchemaLock] { get }
}

public struct ActorSystemCompilationRequest: Sendable {
    public let sourceFiles: [URL]
    public let sourceRoot: URL?
    public let moduleName: String
    public let packageIdentity: String
    public let profile: ActorGenerationProfile
    public let schemaLockURL: URL
    public let outputDirectory: URL
    public let toolchainFingerprint: String
    public let expectedToolchainFingerprint: String?
    public let compilerTargetMappingProvider: any ActorCompilerTargetMappingProvider
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
        compilerTargetMappingProvider: any ActorCompilerTargetMappingProvider,
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
        self.compilerTargetMappingProvider = compilerTargetMappingProvider
        self.dependencySchemas = dependencySchemas
        self.distributedActorSystemTypeName = distributedActorSystemTypeName
        self.includedActorSystemTypeNames = includedActorSystemTypeNames
        self.includedActorSymbols = includedActorSymbols
        self.targetEnvironment = targetEnvironment
    }
}

extension ActorSystemCompilationRequest: ActorSystemManifestRequest {}

public struct ActorSystemCompilationResult: Sendable {
    public let schema: ActorSchemaLock
    public let manifest: ActorGeneratedManifest
    public let generatedFiles: [URL]
}

public enum ActorSystemCompiler {
    public static func compile(
        _ request: ActorSystemCompilationRequest
    ) throws -> ActorSystemCompilationResult {
        try validateDependencySchemas(request.dependencySchemas)
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
                    + (isVoid(method.returnType) ? [] : [method.returnType])
                    + (typedErrorType(method.throwsClause).map { [$0] } ?? [])
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
        let mappings = try request.compilerTargetMappingProvider.mappings(for: actors)
        let existing = try ActorSchemaLockStore.load(
            from: request.schemaLockURL,
            packageIdentity: request.packageIdentity,
            moduleName: request.moduleName
        )
        let schema = try ActorSchemaReconciler.reconcile(
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
        var sources = try ActorSourceGenerator.generate(
            actors: actors,
            portableTypes: portableTypes,
            schema: schema,
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
            schema: schema,
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
            to: request.outputDirectory,
            committing: {
                try ActorSchemaLockStore.save(schema, to: request.schemaLockURL)
            }
        )
        return ActorSystemCompilationResult(
            schema: schema,
            manifest: manifest,
            generatedFiles: generatedFiles
        )
    }

    static func validateDependencySchemas(
        _ schemas: [ActorSchemaLock]
    ) throws {
        var modules = Set<String>()
        var canonicalValueIdentities: [String: ActorSchemaLockID128] = [:]
        var valueIDs: [ActorSchemaLockID128: String] = [:]
        for schema in schemas {
            guard !schema.moduleName.isEmpty else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Dependency schema \(schema.packageIdentity) has no Swift module name"
                )
            }
            guard modules.insert(schema.moduleName).inserted else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Dependency actor schema module \(schema.moduleName) was provided more than once"
                )
            }
            for value in schema.valueTypes {
                if let existing = canonicalValueIdentities[value.canonicalType],
                   existing != value.typeID {
                    throw ActorGenerationError.schemaConflict(
                        reason: "Dependency value \(value.canonicalType) has conflicting type IDs"
                    )
                }
                if let existing = valueIDs[value.typeID],
                   existing != value.canonicalType {
                    throw ActorGenerationError.schemaConflict(
                        reason: "Dependency value type ID is shared by \(existing) and \(value.canonicalType)"
                    )
                }
                canonicalValueIdentities[value.canonicalType] = value.typeID
                valueIDs[value.typeID] = value.canonicalType
            }
        }
    }

    static func makeManifest<Request: ActorSystemManifestRequest>(
        request: Request,
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        schema: ActorSchemaLock,
        toolchainFingerprint: String,
        generatedSources: [GeneratedActorSource]
    ) throws -> ActorGeneratedManifest {
        let sourceRoot = try request.sourceRoot?.standardizedFileURL
            ?? commonSourceRoot(request.sourceFiles)
        let actorsByPath = Dictionary(grouping: actors, by: { URL(fileURLWithPath: $0.sourcePath).standardizedFileURL.path })
        let valuesByPath = Dictionary(grouping: portableTypes, by: { URL(fileURLWithPath: $0.sourcePath).standardizedFileURL.path })
        let inputs = try request.sourceFiles
            .map(\.standardizedFileURL)
            .sorted { $0.path < $1.path }
            .map { sourceURL in
                let source = try String(contentsOf: sourceURL, encoding: .utf8)
                let actorNames = request.profile == .nativeHost
                    ? []
                    : (actorsByPath[sourceURL.path] ?? []).map(\.name).sorted()
                let portableNames = request.profile == .standardClient
                    || request.profile == .embeddedHost
                    || request.profile == .embeddedClient
                    ? (valuesByPath[sourceURL.path] ?? []).map(\.name).sorted()
                    : []
                return ActorGeneratedManifest.InputSource(
                    relativePath: try relativePath(from: sourceRoot, to: sourceURL),
                    contentDigest: ActorStableHash.digest(source),
                    replacedActorNames: actorNames,
                    replacedPortableTypeNames: portableNames
                )
            }
        let outputs = generatedSources
            .map {
                ActorGeneratedManifest.GeneratedFile(
                    relativePath: $0.relativePath,
                    contentDigest: ActorStableHash.digest($0.contents)
                )
            }
            .sorted { $0.relativePath < $1.relativePath }
        let dependencies = try request.dependencySchemas.map { dependency in
            ActorGeneratedManifest.DependencySchema(
                packageIdentity: dependency.packageIdentity,
                moduleName: dependency.moduleName,
                contentDigest: try digest(dependency),
                bootstrapTypeName: ActorGeneratedNames.bootstrapTypeName(
                    moduleName: dependency.moduleName
                )
            )
        }.sorted {
            if $0.packageIdentity == $1.packageIdentity {
                return $0.moduleName < $1.moduleName
            }
            return $0.packageIdentity < $1.packageIdentity
        }
        let bootstrapTypeName: String?
        switch request.profile {
        case .nativeHost, .standardClient:
            bootstrapTypeName = ActorGeneratedNames.bootstrapTypeName(
                moduleName: request.moduleName
            )
        case .embeddedHost, .embeddedClient:
            bootstrapTypeName = nil
        }
        return ActorGeneratedManifest(
            packageIdentity: request.packageIdentity,
            moduleName: request.moduleName,
            profile: request.profile,
            toolchainFingerprint: toolchainFingerprint,
            sourceRoot: sourceRoot.path,
            inputSources: inputs,
            generatedFiles: outputs,
            dependencySchemas: dependencies,
            schemaContentDigest: try digest(schema),
            schemaModuleTypeName: ActorGeneratedNames.schemaModuleTypeName(
                moduleName: request.moduleName
            ),
            bootstrapTypeName: bootstrapTypeName
        )
    }

    private static func digest<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return ActorStableHash.digest(String(decoding: data, as: UTF8.self))
    }

    private static func commonSourceRoot(_ sourceFiles: [URL]) throws -> URL {
        guard let first = sourceFiles.first?.standardizedFileURL else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor generation requires at least one source file"
            )
        }
        var components = first.deletingLastPathComponent().pathComponents
        for source in sourceFiles.dropFirst() {
            let candidate = source.standardizedFileURL.deletingLastPathComponent().pathComponents
            var sharedCount = 0
            while sharedCount < components.count,
                  sharedCount < candidate.count,
                  components[sharedCount] == candidate[sharedCount] {
                sharedCount += 1
            }
            components = Array(components.prefix(sharedCount))
        }
        guard !components.isEmpty else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor source files do not share a source root"
            )
        }
        return URL(fileURLWithPath: NSString.path(withComponents: components), isDirectory: true)
            .standardizedFileURL
    }

    private static func relativePath(from root: URL, to source: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let sourcePath = source.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard sourcePath.hasPrefix(prefix) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor source \(sourcePath) is outside \(rootPath)"
            )
        }
        return String(sourcePath.dropFirst(prefix.count))
    }

    private static func typedErrorType(_ throwsClause: String?) -> String? {
        guard let throwsClause,
              let open = throwsClause.firstIndex(of: "("),
              let close = throwsClause.lastIndex(of: ")"),
              open < close
        else {
            return nil
        }
        return String(throwsClause[throwsClause.index(after: open)..<close])
    }

    private static func isVoid(_ type: String) -> Bool {
        type == "Void" || type == "()" || type == "Swift.Void"
    }

}
