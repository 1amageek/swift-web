import SwiftParser
import SwiftSyntax

public enum ActorSourceGenerator {
    public static func generate(
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        schema: ActorSchemaLock,
        toolchainFingerprint: String,
        profile: ActorGenerationProfile,
        targetEnvironment: ActorGenerationTargetEnvironment,
        dependencySchemas: [ActorSchemaLock] = [],
        distributedActorSystemTypeName: String = "SwiftActorSystem"
    ) throws -> [GeneratedActorSource] {
        try validateTargetEnvironment(targetEnvironment, profile: profile)
        try ActorMethodEffectValidator.validatePortableActorContract(actors)
        if profile == .embeddedHost {
            try validateEmbeddedHostPortability(
                actors: actors,
                portableTypes: portableTypes,
                targetEnvironment: targetEnvironment
            )
        }
        let actorEntries = try uniqueDictionary(
            schema.actors.map { ($0.sourceSymbol, $0) },
            label: "actor source symbol"
        )
        let valueEntries = try uniqueDictionary(
            schema.valueTypes.map { ($0.sourceType, $0) },
            label: "value source type"
        )
        let moduleName = try generatedModuleName(
            actors: actors,
            portableTypes: portableTypes,
            packageIdentity: schema.packageIdentity
        )
        let dependencyModuleNames = dependencySchemas.map(\.moduleName)
        var generated: [GeneratedActorSource] = []

        generated.append(
            GeneratedActorSource(
                relativePath: "ActorSchema.generated.swift",
                contents: try descriptorSource(
                    actors: actors,
                    entries: actorEntries,
                    valueEntries: valueEntries,
                    moduleName: moduleName
                )
            )
        )
        if profile == .standardClient
            || profile == .embeddedHost
            || profile == .embeddedClient {
            generated.append(
                GeneratedActorSource(
                    relativePath: "ActorValues.generated.swift",
                    contents: portableValueDeclarationsSource(
                        models: portableTypes,
                        sourceImports: profile == .embeddedHost
                            ? portableTypes.flatMap(\.imports) + dependencyModuleNames
                            : dependencyModuleNames,
                        includesCodable: profile == .standardClient,
                        includesOtherMembers: profile == .embeddedHost
                    )
                )
            )
        }
        generated.append(
            GeneratedActorSource(
                relativePath: "ActorCodecs.generated.swift",
                    contents: try portableCodecSource(
                        models: portableTypes,
                        schema: schema,
                        profile: profile,
                        dependencyModuleNames: dependencyModuleNames
                    )
            )
        )

        switch profile {
        case .nativeHost:
            generated.append(
                GeneratedActorSource(
                    relativePath: "Native/ActorRegistrations.generated.swift",
                    contents: try nativeRegistrationSource(
                        actors: actors,
                        entries: actorEntries,
                        schema: schema,
                        toolchainFingerprint: toolchainFingerprint,
                        moduleName: moduleName,
                        dependencySchemas: dependencySchemas
                    )
                )
            )
        case .standardClient:
            for actor in actors {
                generated.append(
                    GeneratedActorSource(
                        relativePath: "StandardClient/\(actor.name).client.generated.swift",
                        contents: standardClientSource(
                            actor: actor,
                            actorSystemTypeName: distributedActorSystemTypeName,
                            dependencyModuleNames: dependencyModuleNames
                        )
                    )
                )
            }
            generated.append(
                GeneratedActorSource(
                    relativePath: "StandardClient/ActorRegistrations.generated.swift",
                    contents: try nativeRegistrationSource(
                        actors: actors,
                        entries: actorEntries,
                        schema: schema,
                        toolchainFingerprint: toolchainFingerprint,
                        moduleName: moduleName,
                        dependencySchemas: dependencySchemas
                    )
                )
            )
        case .embeddedHost, .embeddedClient:
            for actor in actors {
                guard let entry = actorEntries[actor.symbol] else {
                    throw ActorGenerationError.missingSchemaEntry(symbol: actor.symbol)
                }
                generated.append(
                    GeneratedActorSource(
                        relativePath: "\(profile == .embeddedHost ? "EmbeddedHost" : "EmbeddedClient")/\(actor.name).generated.swift",
                        contents: try embeddedSource(
                            actor: actor,
                            entry: entry,
                            valueEntries: valueEntries,
                            includesHost: profile == .embeddedHost,
                            sourceImports: profile == .embeddedHost
                                ? actor.imports + dependencyModuleNames
                                : dependencyModuleNames
                        )
                    )
                )
            }
        }
        try validateGeneratedReplacementCoverage(
            sources: generated,
            actors: actors,
            portableTypes: portableTypes,
            profile: profile
        )
        return generated
    }

    private static func validateTargetEnvironment(
        _ targetEnvironment: ActorGenerationTargetEnvironment,
        profile: ActorGenerationProfile
    ) throws {
        let isEmbeddedTarget = targetEnvironment.features.contains("Embedded")
        switch profile {
        case .embeddedHost, .embeddedClient:
            guard isEmbeddedTarget else {
                throw ActorGenerationError.invalidTargetEnvironment(
                    reason: "The \(profile.rawValue) profile requires the Embedded compiler feature"
                )
            }
        case .standardClient:
            guard !isEmbeddedTarget else {
                throw ActorGenerationError.invalidTargetEnvironment(
                    reason: "The standardClient profile cannot use an Embedded compiler target"
                )
            }
        case .nativeHost:
            break
        }
    }

    private static func validateGeneratedReplacementCoverage(
        sources: [GeneratedActorSource],
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        profile: ActorGenerationProfile
    ) throws {
        guard profile != .nativeHost else {
            return
        }
        let actorNames = Set(actors.map(\.name))
        let valueNames = Set(portableTypes.map(\.name))
        var actorCounts: [String: Int] = [:]
        var valueCounts: [String: Int] = [:]
        for source in sources {
            let syntax = Parser.parse(source: source.contents)
            for statement in syntax.statements {
                guard case .decl(let declaration) = statement.item else {
                    continue
                }
                if let actor = declaration.as(ActorDeclSyntax.self),
                   actorNames.contains(actor.name.text) {
                    actorCounts[actor.name.text, default: 0] += 1
                }
                if let structure = declaration.as(StructDeclSyntax.self),
                   valueNames.contains(structure.name.text) {
                    valueCounts[structure.name.text, default: 0] += 1
                }
                if let enumeration = declaration.as(EnumDeclSyntax.self),
                   valueNames.contains(enumeration.name.text) {
                    valueCounts[enumeration.name.text, default: 0] += 1
                }
            }
        }
        for name in actorNames where actorCounts[name] != 1 {
            throw ActorGenerationError.schemaConflict(
                reason: "Generated profile \(profile.rawValue) contains \(actorCounts[name, default: 0]) replacements for actor \(name)"
            )
        }
        for name in valueNames where valueCounts[name] != 1 {
            throw ActorGenerationError.schemaConflict(
                reason: "Generated profile \(profile.rawValue) contains \(valueCounts[name, default: 0]) replacements for portable value \(name)"
            )
        }
    }

    private static func descriptorSource(
        actors: [ActorSourceModel],
        entries: [String: ActorSchemaLockActor],
        valueEntries: [String: ActorSchemaLockValueType],
        moduleName: String
    ) throws -> String {
        var lines = ["import ActorSystemCore", ""]
        for actor in actors {
            guard let entry = entries[actor.symbol] else {
                throw ActorGenerationError.missingSchemaEntry(symbol: actor.symbol)
            }
            lines.append("enum \(actor.name)ActorSchema {")
            lines.append("    static let typeID = ActorTypeID(high: \(entry.typeID.high), low: \(entry.typeID.low))")
            lines.append("    static let fingerprint = ActorSchemaFingerprint(high: \(entry.schemaFingerprint.high), low: \(entry.schemaFingerprint.low))")
            for method in entry.methods {
                lines.append("    static let \(methodToken(method))MethodID = ActorMethodID(\(method.methodID))")
            }
            lines.append("    static let descriptor = ActorTypeDescriptor(")
            lines.append("        id: typeID,")
            lines.append("        schemaFingerprint: fingerprint,")
            lines.append("        methods: [")
            for method in entry.methods {
                let parameterIDs = try method.parameters.map { parameter in
                    guard let value = valueEntry(for: parameter.type, in: valueEntries) else {
                        throw ActorGenerationError.missingSchemaEntry(symbol: parameter.type)
                    }
                    return "ActorTypeID(high: \(value.typeID.high), low: \(value.typeID.low))"
                }.joined(separator: ", ")
                let resultID: String
                if isVoid(method.resultType) {
                    resultID = "nil"
                } else if let value = valueEntry(for: method.resultType, in: valueEntries) {
                    resultID = "ActorTypeID(high: \(value.typeID.high), low: \(value.typeID.low))"
                } else {
                    throw ActorGenerationError.missingSchemaEntry(symbol: method.resultType)
                }
                let errorID: String
                if let errorType = typedErrorType(method.errorType),
                   let value = valueEntry(for: errorType, in: valueEntries) {
                    errorID = "ActorTypeID(high: \(value.typeID.high), low: \(value.typeID.low))"
                } else {
                    errorID = "nil"
                }
                lines.append("            ActorMethodDescriptor(id: ActorMethodID(\(method.methodID)), parameterTypeIDs: [\(parameterIDs)], resultTypeID: \(resultID), errorTypeID: \(errorID)),")
            }
            lines.append("        ]")
            lines.append("    )")
            lines.append("}")
            lines.append("")
            lines.append("extension \(actor.name): ActorSystemReference {")
            lines.append("    public nonisolated static var actorTypeID: ActorTypeID { \(actor.name)ActorSchema.typeID }")
            lines.append("    public nonisolated static var actorSchemaFingerprint: ActorSchemaFingerprint { \(actor.name)ActorSchema.fingerprint }")
            lines.append("    public nonisolated static var actorTypeDescriptor: ActorTypeDescriptor { \(actor.name)ActorSchema.descriptor }")
            lines.append("}")
            lines.append("")
        }
        let schemaModuleName = ActorGeneratedNames.schemaModuleTypeName(
            moduleName: moduleName
        )
        lines.append("public enum \(schemaModuleName): ActorSchemaModule {")
        lines.append("    public static let actorTypeDescriptors: [ActorTypeDescriptor] = [")
        for actor in actors {
            lines.append("        \(actor.name)ActorSchema.descriptor,")
        }
        lines.append("    ]")
        lines.append("}")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func nativeRegistrationSource(
        actors: [ActorSourceModel],
        entries: [String: ActorSchemaLockActor],
        schema: ActorSchemaLock,
        toolchainFingerprint: String,
        moduleName: String,
        dependencySchemas: [ActorSchemaLock]
    ) throws -> String {
        var lines = generatedImportLines(
            required: ["ActorSystemCore", "ActorSystemDistributed"],
            source: dependencySchemas.map(\.moduleName),
            excluding: ["Distributed"]
        ) + [
            "",
            "public enum \(ActorGeneratedNames.bootstrapTypeName(moduleName: moduleName)): SwiftActorSystemBootstrap {",
            "    public static let bootstrapIdentifier = \(swiftLiteral(schema.packageIdentity + ":" + moduleName))",
            "    public static let actorTypeDescriptors = \(ActorGeneratedNames.schemaModuleTypeName(moduleName: moduleName)).actorTypeDescriptors",
        ]
        if dependencySchemas.isEmpty {
            lines.append("    public static let dependencies: [any SwiftActorSystemBootstrap.Type] = []")
        } else {
            lines.append("    public static let dependencies: [any SwiftActorSystemBootstrap.Type] = [")
            for dependency in dependencySchemas.sorted(by: {
                if $0.packageIdentity == $1.packageIdentity {
                    return $0.moduleName < $1.moduleName
                }
                return $0.packageIdentity < $1.packageIdentity
            }) {
                let bootstrapTypeName = ActorGeneratedNames.bootstrapTypeName(
                    moduleName: dependency.moduleName
                )
                lines.append("        \(dependency.moduleName).\(bootstrapTypeName).self,")
            }
            lines.append("    ]")
        }
        lines.append("")
        lines.append("    public static func register(in actorSystem: SwiftActorSystem) throws {")
        for value in schema.valueTypes {
            lines.append("        try actorSystem.registerCodec(\(value.sourceType).self, typeID: ActorTypeID(high: \(value.typeID.high), low: \(value.typeID.low)), codec: .portable())")
        }
        for actor in actors {
            guard let entry = entries[actor.symbol] else {
                throw ActorGenerationError.missingSchemaEntry(symbol: actor.symbol)
            }
            lines.append("        let \(lowerIdentifier(actor.name))Aliases = try ActorTargetAliasTable(")
            lines.append("            toolchainFingerprint: \(swiftLiteral(toolchainFingerprint)),")
            lines.append("            aliases: [")
            for method in entry.methods {
                guard let alias = method.compilerTargetAliases.first(where: {
                    $0.toolchainFingerprint == toolchainFingerprint
                }) else {
                    throw ActorGenerationError.missingCompilerTarget(
                        symbol: actor.symbol,
                        method: method.canonicalSignature
                    )
                }
                lines.append("                \(swiftLiteral(alias.targetIdentifier)): ActorMethodID(\(method.methodID)),")
            }
            lines.append("            ]")
            lines.append("        )")
            lines.append("        try actorSystem.register(")
            lines.append("            DistributedActorTypeRegistration(")
            lines.append("                \(actor.name).self,")
            lines.append("                descriptor: \(actor.name)ActorSchema.descriptor,")
            lines.append("                aliases: \(lowerIdentifier(actor.name))Aliases")
            lines.append("            ).eraseToAnyRegistration()")
            lines.append("        )")
        }
        lines.append("    }")
        lines.append("}")
        lines.append("")
        for actor in actors {
            lines.append("extension \(actor.name): SwiftActorSystemBootstrapProvider {")
            lines.append("    public nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type { \(ActorGeneratedNames.bootstrapTypeName(moduleName: moduleName)).self }")
            lines.append("}")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func standardClientSource(
        actor: ActorSourceModel,
        actorSystemTypeName: String,
        dependencyModuleNames: [String]
    ) -> String {
        let actorSystemModuleName = actorSystemTypeName
            .split(separator: ".", omittingEmptySubsequences: true)
            .dropLast()
            .map(String.init)
            .joined(separator: ".")
        let sourceModules = dependencyModuleNames
            + (actorSystemModuleName.isEmpty ? [] : [actorSystemModuleName])
        var lines = generatedImportLines(
            required: ["ActorSystemDistributed", "Distributed"],
            source: sourceModules
        ) + [
            "",
            "\(actor.accessLevel) distributed actor \(actor.name) {",
            "    public typealias ActorSystem = \(actorSystemTypeName)",
            "",
            "    @available(*, unavailable, message: \"This generated projection can only resolve remote actor identities\")",
            "    init(actorSystem: ActorSystem) {",
            "        self.actorSystem = actorSystem",
            "    }",
            "",
        ]
        for method in actor.methods {
            let effects = methodEffects(method)
            lines.append("    \(method.accessLevel) distributed func \(method.name)(\(parameterDeclaration(method.parameters)))\(effects) -> \(method.returnType) {")
            lines.append("        preconditionFailure(\"A standard client projection has no local actor implementation\")")
            lines.append("    }")
            lines.append("")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func embeddedSource(
        actor: ActorSourceModel,
        entry: ActorSchemaLockActor,
        valueEntries: [String: ActorSchemaLockValueType],
        includesHost: Bool,
        sourceImports: [String]
    ) throws -> String {
        guard !includesHost || !actor.initializers.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: actor.symbol,
                reason: "An Embedded host actor requires an explicit initializer"
            )
        }
        if includesHost {
            try validateEmbeddedStoredProperties(actor)
        }

        let stateType = "\(actor.name)EmbeddedState"
        var excludedImports: Set<String> = [
            "Distributed", "ActorSystemDistributed",
        ]
        if !includesHost {
            excludedImports.formUnion(["Foundation", "FoundationEssentials"])
        }
        var lines = generatedImportLines(
            required: ["ActorSystemCore", "ActorSystemEmbedded"],
            source: sourceImports,
            excluding: excludedImports
        ) + [""]
        if includesHost {
            lines.append("private struct \(stateType) {")
            for property in actor.storedProperties {
                lines.append("    var \(property.name): (\(property.type))? = nil")
            }
            lines.append("}")
            lines.append("")
        }

        lines.append("\(actor.accessLevel) actor \(actor.name): EmbeddedActorInstance {")
        lines.append("    public typealias ID = ActorAddress")
        lines.append("    public typealias ActorSystem = EmbeddedActorSystem")
        lines.append("    public nonisolated let id: ID")
        lines.append("    public nonisolated let actorSystem: ActorSystem")
        lines.append("    private nonisolated let location: EmbeddedActorLocation")
        if includesHost {
            lines.append("    private var _actorSystemState: \(stateType)?")
            for property in actor.storedProperties {
                lines.append(contentsOf: embeddedStatePropertySource(property))
            }
            for member in actor.otherMembers {
                lines.append(indent(member, spaces: 4))
            }
        }
        lines.append("")

        if includesHost {
            for initializer in actor.initializers {
                guard initializer.parameters.contains(where: { $0.localName == "actorSystem" }) else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: actor.symbol,
                        reason: "An Embedded host initializer must accept actorSystem"
                    )
                }
                let effects = initializer.effects.isEmpty ? "" : " \(initializer.effects)"
                lines.append("    \(initializer.accessLevel) init(\(parameterDeclaration(initializer.parameters)))\(effects) {")
                lines.append("        self.id = actorSystem.assignID(actorType: ActorTypeID(high: \(entry.typeID.high), low: \(entry.typeID.low)))")
                lines.append("        self.actorSystem = actorSystem")
                lines.append("        self.location = .local")
                lines.append("        self._actorSystemState = \(stateType)()")
                for property in actor.storedProperties {
                    if let initialValue = property.initialValue {
                        lines.append("        self.\(property.name) = \(initialValue)")
                    }
                }
                let body = try embeddedInitializerBody(initializer, actor: actor)
                if !body.isEmpty {
                    lines.append(indent(body, spaces: 8))
                }
                lines.append("        actorSystem.embeddedBackend.registerGenerated(self, target: \(actor.name)EmbeddedTarget(actor: self))")
                lines.append("    }")
                lines.append("")
            }
        }

        lines.append("    private init(id: ID, actorSystem: ActorSystem) {")
        lines.append("        self.id = id")
        lines.append("        self.actorSystem = actorSystem")
        lines.append("        self.location = .remote")
        if includesHost {
            lines.append("        self._actorSystemState = nil")
        }
        lines.append("    }")
        lines.append("")
        lines.append("    public static func resolve(id: ID, using actorSystem: ActorSystem) throws -> \(actor.name) {")
        lines.append("        try actorSystem.resolve(")
        lines.append("            id: id,")
        lines.append("            as: \(actor.name).self")
        lines.append("        ) {")
        lines.append("            \(actor.name)(id: id, actorSystem: actorSystem)")
        lines.append("        }")
        lines.append("    }")
        lines.append("")
        lines.append("    public nonisolated final func whenLocal<Result: Sendable>(")
        lines.append("        _ body: @escaping @Sendable (isolated \(actor.name)) async throws -> Result")
        lines.append("    ) async rethrows -> Result? {")
        lines.append("        guard location == .local else { return nil }")
        lines.append("        return try await _executeWhenLocal(body)")
        lines.append("    }")
        lines.append("")
        lines.append("    private final func _executeWhenLocal<Result: Sendable>(")
        lines.append("        _ body: @escaping @Sendable (isolated \(actor.name)) async throws -> Result")
        lines.append("    ) async rethrows -> Result {")
        lines.append("        try await body(self)")
        lines.append("    }")
        lines.append("")

        for methodModel in actor.methods {
            guard let method = entry.methods.first(where: {
                $0.canonicalSignature == methodModel.canonicalSignature
            }) else {
                throw ActorGenerationError.missingSchemaEntry(symbol: methodModel.canonicalSignature)
            }
            let argumentsType = "\(actor.name)_\(methodToken(method))_Arguments"
            let argumentsExpression = method.parameters.isEmpty
                ? "ActorEmptyArguments()"
                : "\(argumentsType)(\(methodModel.parameters.map { "\($0.localName): \($0.localName)" }.joined(separator: ", ")))"
            lines.append("    \(methodModel.accessLevel) nonisolated func \(methodModel.name)(\(parameterDeclaration(methodModel.parameters))) async throws -> \(methodModel.returnType) {")
            if includesHost {
                lines.append("        if location == .local {")
                let tryPrefix = methodModel.throwsClause == nil ? "" : "try "
                let localCall = "\(tryPrefix)await _invokeLocally_\(methodToken(method))(\(argumentInvocation(methodModel.parameters)))"
                if isVoid(methodModel.returnType) {
                    lines.append("            \(localCall)")
                    lines.append("            return")
                } else {
                    lines.append("            return \(localCall)")
                }
                lines.append("        }")
            }
            let errorArgument = try embeddedErrorCodecArgument(
                method: method,
                valueEntries: valueEntries
            )
            if isVoid(methodModel.returnType) {
                lines.append("        try await actorSystem.invokeVoid(")
            } else {
                lines.append("        return try await actorSystem.invoke(")
            }
            lines.append("            actor: id,")
            lines.append("            method: ActorMethodID(\(method.methodID)),")
            lines.append("            schemaFingerprint: \(actor.name)ActorSchema.fingerprint,")
            lines.append("            argument: \(argumentsExpression),")
            lines.append("            argumentCodec: .portable()\(isVoid(methodModel.returnType) ? errorArgument : ",\n            resultCodec: .portable()" + errorArgument)")
            lines.append("        )")
            lines.append("    }")
            lines.append("")
            if includesHost {
                let effects = [methodModel.isAsync ? "async" : nil, methodModel.throwsClause]
                    .compactMap { $0 }.joined(separator: " ")
                let effectText = effects.isEmpty ? "" : " \(effects)"
                lines.append("    fileprivate func _invokeLocally_\(methodToken(method))(\(parameterDeclaration(methodModel.parameters)))\(effectText) -> \(methodModel.returnType) {")
                lines.append(indent(methodModel.body, spaces: 8))
                lines.append("    }")
                lines.append("")
            }
        }
        lines.append("}")
        lines.append("")
        lines.append("extension \(actor.name): Hashable {")
        lines.append("    public nonisolated static func == (lhs: \(actor.name), rhs: \(actor.name)) -> Bool { lhs.id == rhs.id }")
        lines.append("    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }")
        lines.append("}")
        lines.append("")
        lines.append(contentsOf: try embeddedArgumentsAndTargetSource(
            actor: actor,
            entry: entry,
            valueEntries: valueEntries,
            includesHost: includesHost
        ))
        return lines.joined(separator: "\n")
    }

    private static func embeddedArgumentsAndTargetSource(
        actor: ActorSourceModel,
        entry: ActorSchemaLockActor,
        valueEntries: [String: ActorSchemaLockValueType],
        includesHost: Bool
    ) throws -> [String] {
        var lines: [String] = []
        for (methodIndex, method) in entry.methods.enumerated() {
            guard let source = actor.methods.first(where: { $0.canonicalSignature == method.canonicalSignature }) else {
                throw ActorGenerationError.missingSchemaEntry(symbol: method.canonicalSignature)
            }
            let typeName = "\(actor.name)_\(methodToken(method))_Arguments"
            if !method.parameters.isEmpty {
                lines.append("private struct \(typeName): ActorPortableValue {")
                for (index, parameter) in method.parameters.enumerated() {
                    lines.append("    let \(source.parameters[index].localName): \(parameter.type)")
                }
                lines.append("    func encodeActorValue() throws -> ActorByteBuffer {")
                lines.append("        var encoder = ActorPayloadEncoder()")
                for (index, parameter) in method.parameters.enumerated() {
                    lines.append("        try encoder.append(message: \(source.parameters[index].localName).encodeActorValue(), field: ActorFieldID(\(parameter.fieldID)))")
                }
                lines.append("        return encoder.finish()")
                lines.append("    }")
                lines.append("    static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Self {")
                lines.append("        var decoder = try ActorPayloadDecoder(payload, options: options)")
                for (index, parameter) in method.parameters.enumerated() {
                    lines.append("        guard let field\(index) = try decoder.nextField(), field\(index).id == ActorFieldID(\(parameter.fieldID)), field\(index).wireType == .message else { throw ActorSystemError.decodingFailed }")
                    lines.append("        let value\(index) = try \(parameter.type).decodeActorValue(from: field\(index).payloadBuffer(), options: options.descending())")
                }
                lines.append("        if let _ = try decoder.nextField() { throw ActorSystemError.decodingFailed }")
                lines.append("        return Self(\(source.parameters.enumerated().map { "\($0.element.localName): value\($0.offset)" }.joined(separator: ", ")))")
                lines.append("    }")
                lines.append("}")
                lines.append("")
            }
            _ = methodIndex
        }
        guard includesHost else {
            return lines
        }
        lines.append("private struct \(actor.name)EmbeddedTarget: ActorInvocationTarget {")
        lines.append("    let actor: \(actor.name)")
        lines.append("    var address: ActorAddress { actor.id }")
        lines.append("    let descriptor = \(actor.name)ActorSchema.descriptor")
        lines.append("    func invoke(_ invocation: ActorInvocation, context: ActorInvocationContext) async throws -> ActorInvocationResult {")
        lines.append("        switch invocation.method {")
        for method in entry.methods {
            guard let source = actor.methods.first(where: { $0.canonicalSignature == method.canonicalSignature }) else {
                throw ActorGenerationError.missingSchemaEntry(symbol: method.canonicalSignature)
            }
            let typeName = method.parameters.isEmpty
                ? "ActorEmptyArguments"
                : "\(actor.name)_\(methodToken(method))_Arguments"
            lines.append("        case ActorMethodID(\(method.methodID)):")
            lines.append("            let arguments = try \(typeName).decodeActorValue(from: invocation.payload, options: actor.actorSystem.portableDecodingOptions)")
            let arguments = source.parameters.enumerated().map { index, parameter in
                let label = parameter.externalName == "_" ? "" : "\(parameter.externalName): "
                return "\(label)arguments.\(parameter.localName)"
            }.joined(separator: ", ")
            let tryPrefix = source.throwsClause == nil ? "" : "try "
            let call = "\(tryPrefix)await actor._invokeLocally_\(methodToken(method))(\(arguments))"
            let errorType = typedErrorType(method.errorType)
            if errorType != nil {
                lines.append("            do {")
            }
            let indentation = errorType == nil ? "            " : "                "
            if isVoid(method.resultType) {
                lines.append("\(indentation)\(call)")
                lines.append("\(indentation)return ActorInvocationResult()")
            } else {
                lines.append("\(indentation)let result = \(call)")
                lines.append("\(indentation)return ActorInvocationResult(payload: try result.encodeActorValue())")
            }
            if let errorType {
                guard let errorEntry = valueEntry(for: errorType, in: valueEntries) else {
                    throw ActorGenerationError.missingSchemaEntry(symbol: errorType)
                }
                lines.append("            } catch let error as \(errorType) {")
                lines.append("                throw ActorApplicationFailure(")
                lines.append("                    typeID: ActorTypeID(high: \(errorEntry.typeID.high), low: \(errorEntry.typeID.low)),")
                lines.append("                    payload: try error.encodeActorValue()")
                lines.append("                )")
                lines.append("            }")
            }
        }
        lines.append("        default:")
        lines.append("            throw ActorSystemError.targetUnavailable(invocation.method)")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        return lines
    }

    private static func portableCodecSource(
        models: [ActorPortableTypeModel],
        schema: ActorSchemaLock,
        profile: ActorGenerationProfile,
        dependencyModuleNames: [String]
    ) throws -> String {
        var excludedImports: Set<String> = ["Distributed", "ActorSystemDistributed"]
        if profile == .embeddedHost || profile == .embeddedClient {
            excludedImports.formUnion(["Foundation", "FoundationEssentials"])
        }
        var lines = generatedImportLines(
            required: ["ActorSystemCore"],
            source: dependencyModuleNames,
            excluding: excludedImports
        ) + [""]
        let entries = try uniqueDictionary(
            schema.valueTypes.map { ($0.sourceType, $0) },
            label: "value source type"
        )
        for model in models {
            guard let entry = valueEntry(for: model.name, in: entries) else {
                continue
            }
            switch model.kind {
            case .structure(let fields):
                lines.append(contentsOf: portableStructSource(model: model, fields: fields, entry: entry))
            case .enumeration(let cases):
                lines.append(contentsOf: portableEnumSource(model: model, cases: cases, entry: entry))
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func portableValueDeclarationsSource(
        models: [ActorPortableTypeModel],
        sourceImports: [String],
        includesCodable: Bool,
        includesOtherMembers: Bool
    ) -> String {
        var excludedImports: Set<String> = [
            "Distributed", "ActorSystemDistributed",
        ]
        if !includesOtherMembers {
            excludedImports.formUnion(["Foundation", "FoundationEssentials"])
        }
        var lines = generatedImportLines(
            required: [],
            source: sourceImports,
            excluding: excludedImports
        )
        if !lines.isEmpty {
            lines.append("")
        }
        for model in models {
            let conformances = (includesCodable ? ["Codable"] : [])
                + model.conformances
            let inheritance = conformances.isEmpty
                ? ""
                : ": " + conformances.joined(separator: ", ")
            switch model.kind {
            case .structure(let fields):
                lines.append("\(model.accessLevel) struct \(model.name)\(inheritance) {")
                for field in fields {
                    lines.append(indent(field.source, spaces: 4))
                }
                if includesOtherMembers {
                    for member in model.otherMembers {
                        lines.append(indent(member, spaces: 4))
                    }
                }
                lines.append("}")
            case .enumeration(let cases):
                lines.append("\(model.accessLevel) enum \(model.name)\(inheritance) {")
                for schemaCase in cases {
                    let indirect = schemaCase.isIndirect ? "indirect " : ""
                    lines.append("    \(indirect)case \(schemaCase.sourceElement)")
                }
                if includesOtherMembers {
                    for member in model.otherMembers {
                        lines.append(indent(member, spaces: 4))
                    }
                }
                lines.append("}")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func portableStructSource(
        model: ActorPortableTypeModel,
        fields: [ActorPortableFieldModel],
        entry: ActorSchemaLockValueType
    ) -> [String] {
        let witnessAccess = model.accessLevel == "public" || model.accessLevel == "open" ? "public " : ""
        var lines = ["extension \(model.name): ActorPortableValue {"]
        lines.append("    \(witnessAccess)func encodeActorValue() throws -> ActorByteBuffer {")
        lines.append("        var encoder = ActorPayloadEncoder()")
        for field in entry.fields {
            lines.append("        try encoder.append(message: \(field.sourceName).encodeActorValue(), field: ActorFieldID(\(field.fieldID)))")
        }
        lines.append("        return encoder.finish()")
        lines.append("    }")
        lines.append("    \(witnessAccess)static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Self {")
        lines.append("        var decoder = try ActorPayloadDecoder(payload, options: options)")
        for field in entry.fields {
            lines.append("        var _\(field.sourceName): \(field.type)?")
        }
        lines.append("        while let field = try decoder.nextField() {")
        lines.append("            switch field.id {")
        for field in entry.fields {
            lines.append("            case ActorFieldID(\(field.fieldID)):")
            lines.append("                guard field.wireType == .message else { throw ActorSystemError.decodingFailed }")
                lines.append("                _\(field.sourceName) = try \(field.type).decodeActorValue(from: field.payloadBuffer(), options: options.descending())")
        }
        lines.append("            default: continue")
        lines.append("            }")
        lines.append("        }")
        for field in entry.fields {
            if field.isOptional {
                lines.append("        let \(field.sourceName): \(field.type) = _\(field.sourceName) ?? nil")
            } else if let defaultValue = field.defaultValue {
                lines.append("        let \(field.sourceName): \(field.type) = _\(field.sourceName) ?? \(defaultValue)")
            } else {
                lines.append("        guard let \(field.sourceName) = _\(field.sourceName) else { throw ActorSystemError.decodingFailed }")
            }
        }
        let decodedArguments = fields.map {
            "_actorSystemDecoded_\($0.name): \($0.name)"
        }.joined(separator: ", ")
        if fields.isEmpty {
            lines.append("        return Self(_actorSystemDecoded: ())")
        } else {
            lines.append("        return Self(\(decodedArguments))")
        }
        lines.append("    }")
        if fields.isEmpty {
            lines.append("    private init(_actorSystemDecoded: Void) {}")
        } else {
            lines.append("    private init(\(fields.map { "_actorSystemDecoded_\($0.name) \($0.name): \($0.type)" }.joined(separator: ", "))) {")
            for field in fields {
                lines.append("        self.\(field.name) = \(field.name)")
            }
            lines.append("    }")
        }
        lines.append("}")
        return lines
    }

    private static func portableEnumSource(
        model: ActorPortableTypeModel,
        cases: [ActorPortableCaseModel],
        entry: ActorSchemaLockValueType
    ) -> [String] {
        let witnessAccess = model.accessLevel == "public" || model.accessLevel == "open" ? "public " : ""
        var lines = ["extension \(model.name): ActorPortableValue {"]
        lines.append("    \(witnessAccess)func encodeActorValue() throws -> ActorByteBuffer {")
        lines.append("        var associated = ActorPayloadEncoder()")
        lines.append("        let caseID: UInt32")
        lines.append("        switch self {")
        for schemaCase in entry.cases {
            let modelCase = cases.first(where: { $0.name == schemaCase.sourceName })
            let bindings = (modelCase?.associatedValues ?? []).indices.map { "value\($0)" }
            lines.append("        case .\(schemaCase.sourceName)\(bindings.isEmpty ? "" : "(" + bindings.joined(separator: ", ") + ")"):")
            lines.append("            caseID = \(schemaCase.caseID)")
            for (index, parameter) in schemaCase.associatedValues.enumerated() {
                lines.append("            try associated.append(message: value\(index).encodeActorValue(), field: ActorFieldID(\(parameter.fieldID)))")
            }
        }
        lines.append("        }")
        lines.append("        var encoder = ActorPayloadEncoder()")
        lines.append("        try encoder.appendEnumeration(caseID: caseID, associatedValues: associated.finish(), field: ActorFieldID(1))")
        lines.append("        return encoder.finish()")
        lines.append("    }")
        lines.append("    \(witnessAccess)static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Self {")
        lines.append("        var decoder = try ActorPayloadDecoder(payload, options: options)")
        lines.append("        guard let field = try decoder.nextField(), field.id == ActorFieldID(1), field.wireType == .enumeration else { throw ActorSystemError.decodingFailed }")
        lines.append("        if let _ = try decoder.nextField() { throw ActorSystemError.decodingFailed }")
        lines.append("        var decoded = try field.decodeEnumeration()")
        lines.append("        let associatedOptions = try options.descending()")
        lines.append("        switch decoded.caseID {")
        for schemaCase in entry.cases {
            let modelCase = cases.first(where: { $0.name == schemaCase.sourceName })
            lines.append("        case \(schemaCase.caseID):")
            for (index, parameter) in schemaCase.associatedValues.enumerated() {
                lines.append("            guard let field\(index) = try decoded.associatedValues.nextField(), field\(index).id == ActorFieldID(\(parameter.fieldID)), field\(index).wireType == .message else { throw ActorSystemError.decodingFailed }")
                lines.append("            let value\(index) = try \(parameter.type).decodeActorValue(from: field\(index).payloadBuffer(), options: associatedOptions.descending())")
            }
            lines.append("            if let _ = try decoded.associatedValues.nextField() { throw ActorSystemError.decodingFailed }")
            let values = (modelCase?.associatedValues ?? []).enumerated().map { index, value in
                value.label.map { "\($0): value\(index)" } ?? "value\(index)"
            }.joined(separator: ", ")
            lines.append("            return .\(schemaCase.sourceName)\(values.isEmpty ? "" : "(" + values + ")")")
        }
        lines.append("        default: throw ActorSystemError.decodingFailed")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        return lines
    }

    private static func embeddedErrorCodecArgument(
        method: ActorSchemaLockMethod,
        valueEntries: [String: ActorSchemaLockValueType]
    ) throws -> String {
        guard let errorType = typedErrorType(method.errorType) else {
            return ""
        }
        guard let entry = valueEntry(for: errorType, in: valueEntries) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: errorType)
        }
        return ",\n            errorCodec: EmbeddedActorErrorCodec(typeID: ActorTypeID(high: \(entry.typeID.high), low: \(entry.typeID.low)), codec: .portable())"
    }

    private static func valueEntry(
        for sourceType: String,
        in entries: [String: ActorSchemaLockValueType]
    ) -> ActorSchemaLockValueType? {
        entries[sourceType] ?? entries[sourceType.split(separator: ".").last.map(String.init) ?? sourceType]
    }

    private static func validateEmbeddedStoredProperties(
        _ actor: ActorSourceModel
    ) throws {
        let unsupportedModifiers: Set<String> = [
            "lazy",
            "weak",
            "unowned",
            "nonisolated",
        ]
        for property in actor.storedProperties {
            if property.hasAttributes {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(actor.symbol).\(property.name)",
                    reason: "Stored-property attributes cannot be projected to an Embedded actor twin"
                )
            }
            if property.hasObservers {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(actor.symbol).\(property.name)",
                    reason: "Stored-property observers cannot be projected to an Embedded actor twin"
                )
            }
            if let modifier = property.modifiers.first(where: unsupportedModifiers.contains) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(actor.symbol).\(property.name)",
                    reason: "The \(modifier) modifier cannot be projected to an Embedded actor twin"
                )
            }
        }
    }

    private static func validateEmbeddedHostPortability(
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        targetEnvironment: ActorGenerationTargetEnvironment
    ) throws {
        let syntaxOnlyImports: Set<String> = [
            "Distributed", "ActorSystemDistributed",
        ]
        for actor in actors {
            try validateEmbeddedHostImports(
                actor.imports,
                symbol: actor.symbol,
                syntaxOnlyImports: syntaxOnlyImports,
                targetEnvironment: targetEnvironment
            )
            for member in actor.otherMembers {
                try validateEmbeddedHostOtherMember(member, symbol: actor.symbol)
            }
        }
        for portableType in portableTypes {
            try validateEmbeddedHostImports(
                portableType.imports,
                symbol: portableType.symbol,
                syntaxOnlyImports: syntaxOnlyImports,
                targetEnvironment: targetEnvironment
            )
            for member in portableType.otherMembers {
                try validateEmbeddedHostOtherMember(member, symbol: portableType.symbol)
            }
        }
    }

    private static func validateEmbeddedHostImports(
        _ imports: [String],
        symbol: String,
        syntaxOnlyImports: Set<String>,
        targetEnvironment: ActorGenerationTargetEnvironment
    ) throws {
        let unavailableImports = Set(imports)
            .subtracting(syntaxOnlyImports)
            .subtracting(targetEnvironment.availableModules)
            .sorted()
        guard unavailableImports.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "An Embedded host implementation imports unavailable modules: \(unavailableImports.joined(separator: ", "))"
            )
        }
    }

    private static func validateEmbeddedHostOtherMember(
        _ member: String,
        symbol: String
    ) throws {
        let syntax = Parser.parse(source: member)
        if let declaration = embeddedSerializationConformance(in: Syntax(syntax)) {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(symbol).\(declaration)",
                reason: "An Embedded host implementation cannot retain Codable, Encodable, or Decodable conformances"
            )
        }
    }

    private static func embeddedSerializationConformance(
        in syntax: Syntax
    ) -> String? {
        if let declaration = syntax.as(StructDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.name.text
        }
        if let declaration = syntax.as(EnumDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.name.text
        }
        if let declaration = syntax.as(ClassDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.name.text
        }
        if let declaration = syntax.as(ProtocolDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.name.text
        }
        if let declaration = syntax.as(ActorDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.name.text
        }
        if let declaration = syntax.as(ExtensionDeclSyntax.self),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            declaration.inheritanceClause
           ) {
            return declaration.extendedType.trimmedDescription
        }
        for child in syntax.children(viewMode: .sourceAccurate) {
            if let declaration = embeddedSerializationConformance(in: child) {
                return declaration
            }
        }
        return nil
    }

    private static func embeddedStatePropertySource(
        _ property: ActorStoredPropertyModel
    ) -> [String] {
        let setterAccess: String
        if property.isImmutable,
           property.accessLevel != "private" {
            setterAccess = " private(set)"
        } else {
            setterAccess = ""
        }
        let declaration = "\(property.accessLevel)\(setterAccess) var \(property.name): \(property.type)"
        let unavailableMessage = swiftLiteral(
            "Embedded local state for \(property.name) is unavailable on a remote actor reference"
        )
        var lines = [
            "",
            "    \(declaration) {",
            "        get {",
            "            guard let state = _actorSystemState, let value = state.\(property.name) else {",
            "                preconditionFailure(\(unavailableMessage))",
            "            }",
            "            return value",
            "        }",
            "        set {",
            "            guard var state = _actorSystemState else {",
            "                preconditionFailure(\(unavailableMessage))",
            "            }",
        ]
        if property.isImmutable {
            let immutableMessage = swiftLiteral(
                "Embedded immutable state for \(property.name) was assigned more than once"
            )
            lines.append("            guard case .none = state.\(property.name) else {")
            lines.append("                preconditionFailure(\(immutableMessage))")
            lines.append("            }")
        }
        lines.append("            state.\(property.name) = .some(newValue)")
        lines.append("            _actorSystemState = state")
        lines.append("        }")
        lines.append("    }")
        return lines
    }

    private static func embeddedInitializerBody(
        _ initializer: ActorInitializerModel,
        actor: ActorSourceModel
    ) throws -> String {
        var actorSystemAssignments = 0
        var retainedStatements: [String] = []
        for statement in initializer.bodyStatements {
            if normalizedStatement(statement) == "self.actorSystem=actorSystem" {
                actorSystemAssignments += 1
            } else {
                retainedStatements.append(statement)
            }
        }
        guard actorSystemAssignments == 1 else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: actor.symbol,
                reason: "An Embedded host initializer must contain exactly one direct 'self.actorSystem = actorSystem' assignment"
            )
        }
        return retainedStatements.joined(separator: "\n")
    }

    private static func normalizedStatement(_ statement: String) -> String {
        var normalized = statement.filter { !$0.isWhitespace }
        while normalized.last == ";" {
            normalized.removeLast()
        }
        return normalized
    }

    private static func parameterDeclaration(_ parameters: [ActorParameterModel]) -> String {
        parameters.map { parameter in
            let names = parameter.externalName == parameter.localName
                ? parameter.externalName
                : "\(parameter.externalName) \(parameter.localName)"
            let defaultValue = parameter.defaultValue.map { " = \($0)" } ?? ""
            return "\(names): \(parameter.type)\(defaultValue)"
        }.joined(separator: ", ")
    }

    private static func methodEffects(_ method: ActorMethodModel) -> String {
        let effects = [
            method.isAsync ? "async" : nil,
            method.throwsClause,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        return effects.isEmpty ? "" : " \(effects)"
    }

    private static func argumentInvocation(_ parameters: [ActorParameterModel]) -> String {
        parameters.map { parameter in
            parameter.externalName == "_"
                ? parameter.localName
                : "\(parameter.externalName): \(parameter.localName)"
        }.joined(separator: ", ")
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

    private static func safeIdentifier(_ value: String) -> String {
        let mapped = value.map { character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        }
        let result = String(mapped)
        return result.first?.isNumber == true ? "_\(result)" : result
    }

    private static func methodToken(_ method: ActorSchemaLockMethod) -> String {
        "\(safeIdentifier(method.sourceName))_\(method.methodID)"
    }

    private static func lowerIdentifier(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func swiftLiteral(_ value: String) -> String {
        var result = "\""
        for character in value {
            switch character {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default: result.append(character)
            }
        }
        result += "\""
        return result
    }

    private static func generatedImportLines(
        required: [String],
        source: [String],
        excluding: Set<String> = []
    ) -> [String] {
        Array(Set(required + source).subtracting(excluding))
            .sorted()
            .map { "import \($0)" }
    }

    private static func indent(_ source: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }

    private static func uniqueDictionary<Key: Hashable, Value>(
        _ pairs: [(Key, Value)],
        label: String
    ) throws -> [Key: Value] {
        var result: [Key: Value] = [:]
        for (key, value) in pairs {
            guard result.updateValue(value, forKey: key) == nil else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Duplicate \(label) entry"
                )
            }
        }
        return result
    }

    private static func generatedModuleName(
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        packageIdentity: String
    ) throws -> String {
        let names = Set(actors.map(\.moduleName) + portableTypes.map(\.moduleName))
        guard names.count <= 1 else {
            throw ActorGenerationError.schemaConflict(
                reason: "One generation request cannot contain declarations from multiple modules"
            )
        }
        return names.first ?? packageIdentity
    }
}
