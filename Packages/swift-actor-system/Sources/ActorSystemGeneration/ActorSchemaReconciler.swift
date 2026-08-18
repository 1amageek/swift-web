import Foundation

public enum ActorSchemaReconciler {
    public static func reconcile(
        actors: [ActorSourceModel],
        packageIdentity: String,
        moduleName: String? = nil,
        toolchainFingerprint: String,
        compilerTargets: [ActorCompilerTargetMapping],
        portableTypes: [ActorPortableTypeModel] = [],
        dependencyValueTypes: [ActorSchemaLockValueType] = [],
        sourceRoot: URL? = nil,
        existing: ActorSchemaLock
    ) throws -> ActorSchemaLock {
        try ActorMethodEffectValidator.validatePortableActorContract(actors)
        guard existing.packageIdentity == packageIdentity else {
            throw ActorGenerationError.schemaConflict(reason: "Package identity does not match the schema lock")
        }
        let resolvedModuleName = try resolvedModuleName(
            explicit: moduleName,
            actors: actors,
            portableTypes: portableTypes,
            existing: existing
        )
        guard existing.moduleName.isEmpty || existing.moduleName == resolvedModuleName else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor schema module changed from \(existing.moduleName) to \(resolvedModuleName)"
            )
        }
        let mappings = try uniqueDictionary(
            compilerTargets.map { ($0.key, $0.targetIdentifier) },
            label: "compiler target"
        )
        let existingActors = try uniqueDictionary(
            existing.actors.map { ($0.sourceSymbol, $0) },
            label: "actor source symbol"
        )
        var reservedActorIDs = Set(existing.reservedActorTypeIDs)
        var reservedValueTypeIDs = Set(existing.reservedValueTypeIDs)
        var reservedMethodIDs = Set(existing.reservedMethodIDs)
        let currentSymbols = Set(actors.map(\.symbol))
        for removed in existing.actors where !currentSymbols.contains(removed.sourceSymbol) {
            reservedActorIDs.insert(removed.typeID)
            reservedMethodIDs.formUnion(removed.methods.map(\.methodID))
        }

        var occupiedActorIDs = reservedActorIDs
        var occupiedValueTypeIDs = reservedValueTypeIDs
        var occupiedMethodIDs = reservedMethodIDs
        var reconciledActors: [ActorSchemaLockActor] = []

        let actorTypeReferences = try uniqueDictionary(
            actors.map { actor in
                (actor.symbol, try reachableTypes(for: actor, portableTypes: portableTypes))
            },
            label: "actor type-reference graph"
        )
        let reachableTypeNames = actorTypeReferences.values.reduce(into: Set<String>()) {
            $0.formUnion($1)
        }
        let existingValueTypes = try uniqueDictionary(
            existing.valueTypes.map { ($0.sourceType, $0) },
            label: "value source type"
        )
        let dependencyValueTypesByName = try uniqueDictionary(
            dependencyValueTypes.map { ($0.canonicalType, $0) },
            label: "dependency canonical value type",
            allowingIdenticalValues: true
        )
        let portableTypesByName = try uniqueDictionary(
            portableTypes.flatMap { model in
                [(model.name, model), (model.symbol, model)]
            },
            label: "portable source type"
        )
        for removed in existing.valueTypes where !reachableTypeNames.contains(removed.sourceType) {
            reservedValueTypeIDs.insert(removed.typeID)
            occupiedValueTypeIDs.insert(removed.typeID)
        }
        var valueTypes: [ActorSchemaLockValueType] = []
        let canonicalTypes = ActorCanonicalTypeResolver(
            localTypes: portableTypes,
            dependencyTypes: dependencyValueTypes
        )
        for sourceType in reachableTypeNames.sorted() {
            let previous = existingValueTypes[sourceType]
            let canonicalType = try canonicalTypes.canonicalType(for: sourceType)
            if let previous, previous.canonicalType != canonicalType {
                throw ActorGenerationError.schemaConflict(
                    reason: "Canonical value identity changed from \(previous.canonicalType) to \(canonicalType)"
                )
            }
            let dependency = try dependencyValueType(
                named: sourceType,
                canonicalType: canonicalType,
                in: dependencyValueTypesByName
            )
            let typeID = previous?.typeID ?? dependency?.typeID
                ?? ActorStableHash.hash128("portable-value:\(canonicalType)")
            guard occupiedValueTypeIDs.insert(typeID).inserted || previous?.typeID == typeID else {
                throw ActorGenerationError.schemaConflict(reason: "Value type ID collision for \(sourceType)")
            }
            let portableModel = portableTypesByName[sourceType]
            let previousFields = try uniqueDictionary(
                (previous?.fields ?? []).map { ($0.sourceName, $0) },
                label: "value field"
            )
            let previousCases = try uniqueDictionary(
                (previous?.cases ?? []).map { ($0.sourceName, $0) },
                label: "enum case"
            )
            let fields: [ActorSchemaLockValueField]
            let cases: [ActorSchemaLockValueCase]
            var reservedFieldIDs = Set(previous?.reservedFieldIDs ?? [])
            var reservedCaseIDs = Set(previous?.reservedCaseIDs ?? [])
            switch portableModel?.kind {
            case .structure(let sourceFields):
                let currentNames = Set(sourceFields.map(\.name))
                reservedFieldIDs.formUnion(
                    (previous?.fields ?? [])
                        .filter { !currentNames.contains($0.sourceName) }
                        .map(\.fieldID)
                )
                var occupied = reservedFieldIDs.union(previousFields.values.map(\.fieldID))
                fields = try sourceFields.map { field in
                    let fieldID = try previousFields[field.name]?.fieldID
                        ?? nextAvailableID(occupied: &occupied)
                    return ActorSchemaLockValueField(
                        fieldID: fieldID,
                        sourceName: field.name,
                        type: field.type,
                        isOptional: field.type.hasSuffix("?"),
                        defaultValue: field.defaultValue
                    )
                }
                cases = []
            case .enumeration(let sourceCases):
                fields = []
                let currentNames = Set(sourceCases.map(\.name))
                reservedCaseIDs.formUnion(
                    (previous?.cases ?? [])
                        .filter { !currentNames.contains($0.sourceName) }
                        .map(\.caseID)
                )
                var occupied = reservedCaseIDs.union(previousCases.values.map(\.caseID))
                cases = try sourceCases.map { sourceCase in
                    let previousCase = previousCases[sourceCase.name]
                    let caseID = try previousCase?.caseID
                        ?? nextAvailableID(occupied: &occupied)
                    var reservedAssociatedIDs = Set(
                        previousCase?.reservedAssociatedValueFieldIDs ?? []
                    )
                    if let previousCase,
                       previousCase.associatedValues.count > sourceCase.associatedValues.count {
                        reservedAssociatedIDs.formUnion(
                            previousCase.associatedValues
                                .dropFirst(sourceCase.associatedValues.count)
                                .map(\.fieldID)
                        )
                    }
                    var occupiedAssociated = reservedAssociatedIDs.union(
                        (previousCase?.associatedValues ?? []).map(\.fieldID)
                    )
                    return ActorSchemaLockValueCase(
                        caseID: caseID,
                        sourceName: sourceCase.name,
                        associatedValues: try sourceCase.associatedValues.enumerated().map { valueIndex, value in
                            ActorSchemaLockParameter(
                                fieldID: try previousCase?.associatedValues[safe: valueIndex]?.fieldID
                                    ?? nextAvailableID(occupied: &occupiedAssociated),
                                label: value.label ?? "_",
                                type: value.type
                            )
                        },
                        reservedAssociatedValueFieldIDs: Array(reservedAssociatedIDs).sorted()
                    )
                }
            case nil:
                fields = previous?.fields ?? dependency?.fields ?? []
                cases = previous?.cases ?? dependency?.cases ?? []
                reservedFieldIDs = Set(
                    previous?.reservedFieldIDs ?? dependency?.reservedFieldIDs ?? []
                )
                reservedCaseIDs = Set(
                    previous?.reservedCaseIDs ?? dependency?.reservedCaseIDs ?? []
                )
            }
            valueTypes.append(
                ActorSchemaLockValueType(
                    sourceType: sourceType,
                    canonicalType: canonicalType,
                    typeID: typeID,
                    fields: fields,
                    cases: cases,
                    reservedFieldIDs: Array(reservedFieldIDs).sorted(),
                    reservedCaseIDs: Array(reservedCaseIDs).sorted()
                )
            )
        }

        for actor in actors {
            let previous = existingActors[actor.symbol]
            let typeID = previous?.typeID
                ?? ActorStableHash.hash128("actor:\(packageIdentity):\(actor.symbol)")
            guard occupiedActorIDs.insert(typeID).inserted || previous?.typeID == typeID else {
                throw ActorGenerationError.schemaConflict(reason: "Actor type ID collision for \(actor.symbol)")
            }

            let previousMethods = try uniqueDictionary(
                (previous?.methods ?? []).map { ($0.canonicalSignature, $0) },
                label: "actor method signature"
            )
            let currentSignatures = Set(actor.methods.map(\.canonicalSignature))
            for removed in previous?.methods ?? []
            where !currentSignatures.contains(removed.canonicalSignature) {
                reservedMethodIDs.insert(removed.methodID)
                occupiedMethodIDs.insert(removed.methodID)
            }

            var methods: [ActorSchemaLockMethod] = []
            for method in actor.methods.sorted(by: { $0.canonicalSignature < $1.canonicalSignature }) {
                let previousMethod = previousMethods[method.canonicalSignature]
                let methodID = previousMethod?.methodID
                    ?? ActorStableHash.hash64("method:\(packageIdentity):\(actor.symbol):\(method.canonicalSignature)")
                guard occupiedMethodIDs.insert(methodID).inserted || previousMethod?.methodID == methodID else {
                    throw ActorGenerationError.schemaConflict(
                        reason: "Actor method ID collision for \(actor.symbol).\(method.name)"
                    )
                }
                let key = ActorCompilerTargetKey(
                    actorSymbol: actor.symbol,
                    canonicalMethodSignature: method.canonicalSignature
                )
                guard let compilerTarget = mappings[key] else {
                    throw ActorGenerationError.missingCompilerTarget(
                        symbol: actor.symbol,
                        method: method.canonicalSignature
                    )
                }
                var aliases = previousMethod?.compilerTargetAliases ?? []
                aliases.removeAll { $0.toolchainFingerprint == toolchainFingerprint }
                aliases.append(
                    ActorSchemaLockCompilerAlias(
                        toolchainFingerprint: toolchainFingerprint,
                        targetIdentifier: compilerTarget
                    )
                )
                aliases.sort { $0.toolchainFingerprint < $1.toolchainFingerprint }
                methods.append(
                    ActorSchemaLockMethod(
                        sourceName: method.name,
                        canonicalSignature: method.canonicalSignature,
                        methodID: methodID,
                        parameters: try method.parameters.enumerated().map { index, parameter in
                            guard let fieldID = UInt32(exactly: index + 1) else {
                                throw ActorGenerationError.schemaConflict(
                                    reason: "Actor method has too many parameters"
                                )
                            }
                            return ActorSchemaLockParameter(
                                fieldID: fieldID,
                                label: parameter.externalName,
                                type: parameter.type
                            )
                        },
                        resultType: method.returnType,
                        errorType: method.throwsClause,
                        compilerTargetAliases: aliases
                    )
                )
            }

            let previousFields = try uniqueDictionary(
                (previous?.fields ?? []).map { ($0.sourceName, $0) },
                label: "actor field"
            )
            let currentFieldNames = Set(actor.storedProperties.map(\.name))
            var reservedFieldIDs = Set(previous?.reservedFieldIDs ?? [])
            reservedFieldIDs.formUnion(
                (previous?.fields ?? [])
                    .filter { !currentFieldNames.contains($0.sourceName) }
                    .map(\.fieldID)
            )
            var occupiedFieldIDs = reservedFieldIDs.union(previousFields.values.map(\.fieldID))
            let fields = try actor.storedProperties.map { property in
                ActorSchemaLockField(
                    fieldID: try previousFields[property.name]?.fieldID
                        ?? nextAvailableID(occupied: &occupiedFieldIDs),
                    sourceName: property.name,
                    type: property.type,
                    isOptional: property.type.hasSuffix("?"),
                    hasDefaultValue: property.hasInitialValue
                )
            }
            let referencedTypes = actorTypeReferences[actor.symbol] ?? []
            let currentValues = try uniqueDictionary(
                valueTypes.map { ($0.sourceType, $0) },
                label: "reconciled value source type"
            )
            let currentLayout = wireLayout(
                for: referencedTypes,
                values: currentValues
            )
            let fingerprint: ActorSchemaLockID128
            if let previous,
               try wireLayoutsAreCompatible(
                    referencedTypes: referencedTypes,
                    previousValues: existingValueTypes,
                    currentValues: currentValues
               ) {
                fingerprint = previous.schemaFingerprint
            } else {
                fingerprint = ActorStableHash.hash128(
                    "actor-schema:\(packageIdentity):\(actor.symbol):\(currentLayout)"
                )
            }
            reconciledActors.append(
                ActorSchemaLockActor(
                    moduleName: actor.moduleName,
                    sourceSymbol: actor.symbol,
                    sourcePath: try schemaSourcePath(
                        actor.sourcePath,
                        relativeTo: sourceRoot
                    ),
                    typeID: typeID,
                    schemaFingerprint: fingerprint,
                    methods: methods,
                    fields: fields,
                    reservedFieldIDs: Array(reservedFieldIDs).sorted()
                )
            )
        }

        return ActorSchemaLock(
            packageIdentity: packageIdentity,
            moduleName: resolvedModuleName,
            actors: reconciledActors.sorted { $0.sourceSymbol < $1.sourceSymbol },
            valueTypes: valueTypes,
            reservedActorTypeIDs: Array(reservedActorIDs).sorted(by: idSort),
            reservedValueTypeIDs: Array(reservedValueTypeIDs).sorted(by: idSort),
            reservedMethodIDs: Array(reservedMethodIDs).sorted()
        )
    }

    private static func schemaSourcePath(
        _ sourcePath: String,
        relativeTo sourceRoot: URL?
    ) throws -> String {
        guard let sourceRoot else {
            return sourcePath
        }
        let rootPath = sourceRoot.standardizedFileURL.path
        let absoluteSourcePath = URL(fileURLWithPath: sourcePath).standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard absoluteSourcePath.hasPrefix(prefix) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor source \(absoluteSourcePath) is outside \(rootPath)"
            )
        }
        return String(absoluteSourcePath.dropFirst(prefix.count))
    }

    public static func moveActor(
        in lock: ActorSchemaLock,
        from oldSymbol: String,
        to newSymbol: String
    ) throws -> ActorSchemaLock {
        guard !lock.actors.contains(where: { $0.sourceSymbol == newSymbol }) else {
            throw ActorGenerationError.schemaConflict(reason: "Destination actor symbol already exists")
        }
        guard let index = lock.actors.firstIndex(where: { $0.sourceSymbol == oldSymbol }) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: oldSymbol)
        }
        let ownerModule = lock.moduleName.isEmpty
            ? lock.actors[index].moduleName
            : lock.moduleName
        guard let separator = newSymbol.lastIndex(of: "."),
              separator != newSymbol.startIndex,
              newSymbol.index(after: separator) != newSymbol.endIndex
        else {
            throw ActorGenerationError.schemaConflict(
                reason: "An actor schema symbol must include its Swift module"
            )
        }
        let destinationModule = String(newSymbol[..<separator])
        guard destinationModule == ownerModule else {
            throw ActorGenerationError.schemaConflict(
                reason: "An actor schema lock cannot move an owned actor across Swift modules"
            )
        }
        var updated = lock
        updated.actors[index].sourceSymbol = newSymbol
        updated.actors[index].moduleName = ownerModule
        updated.actors.sort { $0.sourceSymbol < $1.sourceSymbol }
        return updated
    }

    public static func moveValueType(
        in lock: ActorSchemaLock,
        from oldType: String,
        to newType: String
    ) throws -> ActorSchemaLock {
        guard !lock.valueTypes.contains(where: { $0.sourceType == newType }) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Destination value type already exists"
            )
        }
        guard let index = lock.valueTypes.firstIndex(where: { $0.sourceType == oldType }) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: oldType)
        }
        var updated = lock
        updated.valueTypes[index].sourceType = newType
        updated.valueTypes[index].canonicalType = canonicalValueTypeName(
            sourceType: newType,
            moduleName: lock.moduleName
        )
        updated.valueTypes.sort { $0.sourceType < $1.sourceType }
        return updated
    }

    private static func canonicalValueTypeName(
        sourceType: String,
        moduleName: String
    ) -> String {
        guard !sourceType.contains("."), !moduleName.isEmpty else {
            return sourceType
        }
        return "\(moduleName).\(sourceType)"
    }

    public static func moveValueField(
        in lock: ActorSchemaLock,
        valueType: String,
        from oldName: String,
        to newName: String
    ) throws -> ActorSchemaLock {
        guard let typeIndex = lock.valueTypes.firstIndex(where: {
            $0.sourceType == valueType
        }) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: valueType)
        }
        guard !lock.valueTypes[typeIndex].fields.contains(where: {
            $0.sourceName == newName
        }) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Destination value field already exists"
            )
        }
        guard let fieldIndex = lock.valueTypes[typeIndex].fields.firstIndex(where: {
            $0.sourceName == oldName
        }) else {
            throw ActorGenerationError.missingSchemaEntry(
                symbol: "\(valueType).\(oldName)"
            )
        }
        var updated = lock
        updated.valueTypes[typeIndex].fields[fieldIndex].sourceName = newName
        return updated
    }

    public static func moveEnumCase(
        in lock: ActorSchemaLock,
        valueType: String,
        from oldName: String,
        to newName: String
    ) throws -> ActorSchemaLock {
        guard let typeIndex = lock.valueTypes.firstIndex(where: {
            $0.sourceType == valueType
        }) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: valueType)
        }
        guard !lock.valueTypes[typeIndex].cases.contains(where: {
            $0.sourceName == newName
        }) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Destination enum case already exists"
            )
        }
        guard let caseIndex = lock.valueTypes[typeIndex].cases.firstIndex(where: {
            $0.sourceName == oldName
        }) else {
            throw ActorGenerationError.missingSchemaEntry(
                symbol: "\(valueType).\(oldName)"
            )
        }
        var updated = lock
        updated.valueTypes[typeIndex].cases[caseIndex].sourceName = newName
        return updated
    }

    public static func moveActorField(
        in lock: ActorSchemaLock,
        actorSymbol: String,
        from oldName: String,
        to newName: String
    ) throws -> ActorSchemaLock {
        guard let actorIndex = lock.actors.firstIndex(where: {
            $0.sourceSymbol == actorSymbol
        }) else {
            throw ActorGenerationError.missingSchemaEntry(symbol: actorSymbol)
        }
        guard !lock.actors[actorIndex].fields.contains(where: {
            $0.sourceName == newName
        }) else {
            throw ActorGenerationError.schemaConflict(
                reason: "Destination actor field already exists"
            )
        }
        guard let fieldIndex = lock.actors[actorIndex].fields.firstIndex(where: {
            $0.sourceName == oldName
        }) else {
            throw ActorGenerationError.missingSchemaEntry(
                symbol: "\(actorSymbol).\(oldName)"
            )
        }
        var updated = lock
        updated.actors[actorIndex].fields[fieldIndex].sourceName = newName
        return updated
    }

    private static func idSort(_ left: ActorSchemaLockID128, _ right: ActorSchemaLockID128) -> Bool {
        left.high == right.high ? left.low < right.low : left.high < right.high
    }

    private static func nextAvailableID(occupied: inout Set<UInt32>) throws -> UInt32 {
        var candidate: UInt32 = 1
        while occupied.contains(candidate) {
            guard candidate < UInt32.max else {
                throw ActorGenerationError.schemaConflict(
                    reason: "Actor schema field ID space is exhausted"
                )
            }
            candidate += 1
        }
        occupied.insert(candidate)
        return candidate
    }

    private static func uniqueDictionary<Key: Hashable, Value: Equatable>(
        _ pairs: [(Key, Value)],
        label: String,
        allowingIdenticalValues: Bool = false
    ) throws -> [Key: Value] {
        var result: [Key: Value] = [:]
        for (key, value) in pairs {
            if let existing = result[key] {
                if allowingIdenticalValues && existing == value {
                    continue
                }
                throw ActorGenerationError.schemaConflict(
                    reason: "Duplicate \(label) entry"
                )
            }
            result[key] = value
        }
        return result
    }

    private static func isVoid(_ type: String) -> Bool {
        type == "Void" || type == "()" || type == "Swift.Void"
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

    private static func reachableTypes(
        for actor: ActorSourceModel,
        portableTypes: [ActorPortableTypeModel]
    ) throws -> Set<String> {
        var references: Set<String> = []
        for method in actor.methods {
            for parameter in method.parameters {
                references.formUnion(try ActorTypeReferenceScanner.references(in: parameter.type))
            }
            if !isVoid(method.returnType) {
                references.formUnion(try ActorTypeReferenceScanner.references(in: method.returnType))
            }
            if let errorType = typedErrorType(method.throwsClause) {
                references.formUnion(try ActorTypeReferenceScanner.references(in: errorType))
            }
        }

        var expandedModels: Set<String> = []
        var changed = true
        while changed {
            changed = false
            for model in portableTypes where !expandedModels.contains(model.symbol) {
                guard references.contains(model.name) || references.contains(model.symbol) else {
                    continue
                }
                expandedModels.insert(model.symbol)
                let dependencies: [String]
                switch model.kind {
                case .structure(let fields):
                    dependencies = fields.map(\.type)
                case .enumeration(let cases):
                    dependencies = cases.flatMap { $0.associatedValues.map(\.type) }
                }
                for dependency in dependencies {
                    let inserted = try ActorTypeReferenceScanner.references(in: dependency)
                    let oldCount = references.count
                    references.formUnion(inserted)
                    changed = changed || references.count != oldCount
                }
            }
        }
        return references
    }

    private static func wireLayoutsAreCompatible(
        referencedTypes: Set<String>,
        previousValues: [String: ActorSchemaLockValueType],
        currentValues: [String: ActorSchemaLockValueType]
    ) throws -> Bool {
        for sourceType in referencedTypes {
            guard let current = try valueType(named: sourceType, in: currentValues) else {
                continue
            }
            guard let previous = try valueType(named: sourceType, in: previousValues) else {
                continue
            }
            guard valueLayoutIsBackwardCompatible(previous: previous, current: current) else {
                return false
            }
        }
        return true
    }

    private static func valueLayoutIsBackwardCompatible(
        previous: ActorSchemaLockValueType,
        current: ActorSchemaLockValueType
    ) -> Bool {
        let previousFields = Dictionary(uniqueKeysWithValues: previous.fields.map { ($0.fieldID, $0) })
        let currentFields = Dictionary(uniqueKeysWithValues: current.fields.map { ($0.fieldID, $0) })
        for (fieldID, previousField) in previousFields {
            guard let currentField = currentFields[fieldID],
                  currentField.type == previousField.type,
                  currentField.isOptional == previousField.isOptional
            else {
                return false
            }
        }
        for (fieldID, currentField) in currentFields where previousFields[fieldID] == nil {
            guard currentField.isOptional || currentField.defaultValue != nil else {
                return false
            }
        }

        let previousCases = Dictionary(uniqueKeysWithValues: previous.cases.map { ($0.caseID, $0) })
        let currentCases = Dictionary(uniqueKeysWithValues: current.cases.map { ($0.caseID, $0) })
        guard Set(previousCases.keys) == Set(currentCases.keys) else {
            return false
        }
        for (caseID, previousCase) in previousCases {
            guard let currentCase = currentCases[caseID],
                  previousCase.associatedValues.count == currentCase.associatedValues.count
            else {
                return false
            }
            for (previousValue, currentValue) in zip(
                previousCase.associatedValues,
                currentCase.associatedValues
            ) where previousValue.fieldID != currentValue.fieldID
                || previousValue.type != currentValue.type {
                return false
            }
        }
        return true
    }

    private static func resolvedModuleName(
        explicit: String?,
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        existing: ActorSchemaLock
    ) throws -> String {
        let candidates = Set(
            [explicit, existing.moduleName.isEmpty ? nil : existing.moduleName]
                .compactMap { $0 }
                + actors.map(\.moduleName)
                + portableTypes.map(\.moduleName)
        )
        guard candidates.count == 1, let moduleName = candidates.first else {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor schema must identify exactly one Swift module"
            )
        }
        return moduleName
    }

    private static func wireLayout(
        for referencedTypes: Set<String>,
        values: [String: ActorSchemaLockValueType]
    ) -> String {
        referencedTypes.sorted().compactMap { sourceType in
            guard let value = values[sourceType] else {
                return nil
            }
            let fields = value.fields.map {
                "f\($0.fieldID):\($0.type):\($0.isOptional):\($0.defaultValue != nil)"
            }.joined(separator: ",")
            let cases = value.cases.map { schemaCase in
                let associated = schemaCase.associatedValues.map {
                    "a\($0.fieldID):\($0.type)"
                }.joined(separator: ",")
                return "c\(schemaCase.caseID)[\(associated)]"
            }.joined(separator: ",")
            return "\(value.canonicalType)=\(value.typeID.high):\(value.typeID.low){\(fields)}[\(cases)]"
        }.joined(separator: "|")
    }

    private static func valueType(
        named sourceType: String,
        in values: [String: ActorSchemaLockValueType]
    ) throws -> ActorSchemaLockValueType? {
        if let exact = values[sourceType] {
            return exact
        }
        if let canonical = values.values.first(where: {
            $0.canonicalType == sourceType
        }) {
            return canonical
        }
        guard !sourceType.contains(".") else {
            return nil
        }
        let matches = values.values.filter {
            $0.sourceType.split(separator: ".").last.map(String.init) == sourceType
                || $0.canonicalType.split(separator: ".").last.map(String.init) == sourceType
        }
        guard matches.count <= 1 else {
            throw ActorGenerationError.schemaConflict(
                reason: "Value type \(sourceType) is ambiguous: \(matches.map(\.sourceType).sorted().joined(separator: ", "))"
            )
        }
        return matches.first
    }

    private static func dependencyValueType(
        named sourceType: String,
        canonicalType: String,
        in values: [String: ActorSchemaLockValueType]
    ) throws -> ActorSchemaLockValueType? {
        if let exact = values[canonicalType] {
            return exact
        }
        return try valueType(named: sourceType, in: values)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
