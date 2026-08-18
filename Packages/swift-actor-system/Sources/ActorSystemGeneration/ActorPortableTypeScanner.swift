import Foundation
import SwiftParser
import SwiftSyntax

public enum ActorPortableTypeScanner {
    public static func scan(
        sourceFiles: [URL],
        moduleName: String,
        reachableFrom rootTypes: Set<String>? = nil,
        targetEnvironment: ActorGenerationTargetEnvironment? = nil
    ) throws -> [ActorPortableTypeModel] {
        var candidates: [PortableTypeCandidate] = []
        for sourceURL in sourceFiles.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let originalSyntax = Parser.parse(source: source)
            try ActorConditionalCompilationValidator.validatePortableValueSource(
                originalSyntax,
                moduleName: moduleName
            )
            let syntax = try activeSource(
                originalSyntax,
                sourceURL: sourceURL,
                targetEnvironment: targetEnvironment
            )
            let imports = sourceImports(in: syntax)
            for statement in syntax.statements {
                guard case .decl(let declaration) = statement.item else {
                    continue
                }
                if let structure = declaration.as(StructDeclSyntax.self),
                   inheritsCodable(structure.inheritanceClause) {
                    candidates.append(
                        .structure(
                            structure,
                            moduleName: moduleName,
                            sourcePath: sourceURL.path,
                            imports: imports
                        )
                    )
                }
                if let enumeration = declaration.as(EnumDeclSyntax.self),
                   inheritsCodable(enumeration.inheritanceClause) {
                    candidates.append(
                        .enumeration(
                            enumeration,
                            moduleName: moduleName,
                            sourcePath: sourceURL.path,
                            imports: imports
                        )
                    )
                }
            }
        }
        guard let rootTypes else {
            let models = try candidates.map { try $0.model }.sorted { $0.symbol < $1.symbol }
            try rejectExtensions(
                of: Set(models.map(\.name)),
                in: sourceFiles,
                moduleName: moduleName,
                targetEnvironment: targetEnvironment
            )
            return models
        }

        var references: Set<String> = []
        for rootType in rootTypes {
            references.formUnion(try ActorTypeReferenceScanner.references(in: rootType))
        }
        var models: [ActorPortableTypeModel] = []
        var processedSymbols: Set<String> = []
        var changed = true
        while changed {
            changed = false
            for candidate in candidates where !processedSymbols.contains(candidate.symbol) {
                guard references.contains(candidate.name)
                        || references.contains(candidate.symbol)
                else {
                    continue
                }
                let model = try candidate.model
                guard processedSymbols.insert(model.symbol).inserted else {
                    throw ActorGenerationError.schemaConflict(
                        reason: "Portable type \(model.symbol) is declared more than once"
                    )
                }
                models.append(model)
                let dependencies: [String]
                switch model.kind {
                case .structure(let fields):
                    dependencies = fields.map(\.type)
                case .enumeration(let cases):
                    dependencies = cases.flatMap { $0.associatedValues.map(\.type) }
                }
                for dependency in dependencies {
                    let oldCount = references.count
                    references.formUnion(
                        try ActorTypeReferenceScanner.references(in: dependency)
                    )
                    changed = changed || references.count != oldCount
                }
            }
        }
        let sortedModels = models.sorted { $0.symbol < $1.symbol }
        try rejectExtensions(
            of: Set(sortedModels.map(\.name)),
            in: sourceFiles,
            moduleName: moduleName,
            targetEnvironment: targetEnvironment
        )
        return sortedModels
    }

    private static func rejectExtensions(
        of typeNames: Set<String>,
        in sourceFiles: [URL],
        moduleName: String,
        targetEnvironment: ActorGenerationTargetEnvironment?
    ) throws {
        guard !typeNames.isEmpty else {
            return
        }
        for sourceURL in sourceFiles.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let syntax = try activeSource(
                Parser.parse(source: source),
                sourceURL: sourceURL,
                targetEnvironment: targetEnvironment
            )
            for statement in syntax.statements {
                guard case .decl(let declaration) = statement.item,
                      let valueExtension = declaration.as(ExtensionDeclSyntax.self),
                      let typeName = valueExtension.extendedType.trimmedDescription
                        .split(separator: ".").last.map(String.init),
                      typeNames.contains(typeName)
                else {
                    continue
                }
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(moduleName).\(typeName)",
                    reason: "Portable value members must be declared in the value body, not an extension"
                )
            }
        }
    }

    fileprivate static func structureModel(
        _ structure: StructDeclSyntax,
        moduleName: String,
        sourcePath: String,
        imports: [String]
    ) throws -> ActorPortableTypeModel {
        let symbol = "\(moduleName).\(structure.name.text)"
        let structureAccess = accessLevel(structure.modifiers)
        guard structure.attributes.isEmpty,
              structure.modifiers.allSatisfy({ portableTypeModifierNames.contains($0.name.text) })
        else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Struct attributes or declaration modifiers cannot be projected identically to Embedded Swift"
            )
        }
        guard structure.genericParameterClause == nil,
              structure.genericWhereClause == nil else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Generic portable structs are not supported in the first wire profile"
            )
        }
        guard structureAccess != "private", structureAccess != "fileprivate" else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "A generated portable codec must be able to see its value type"
            )
        }
        try validateStructureInheritance(structure.inheritanceClause, symbol: symbol)
        for member in structure.memberBlock.members {
            if let declaration = member.decl.as(EnumDeclSyntax.self),
               declaration.name.text == "CodingKeys" {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom CodingKeys are outside the synthesized portable Codable layout"
                )
            }
            if let function = member.decl.as(FunctionDeclSyntax.self),
               isCustomCodableEncoder(function) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom Codable encoding is not portable to Embedded Swift"
                )
            }
            if let initializer = member.decl.as(InitializerDeclSyntax.self),
               isCustomCodableDecoder(initializer) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom Codable decoding is not portable to Embedded Swift"
                )
            }
        }

        var fields: [ActorPortableFieldModel] = []
        var otherMembers: [String] = []
        for member in structure.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                otherMembers.append(member.decl.trimmedDescription)
                continue
            }
            guard !variable.modifiers.contains(where: { $0.name.text == "static" }) else {
                otherMembers.append(member.decl.trimmedDescription)
                continue
            }
            guard variable.attributes.isEmpty else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Stored-property attributes are outside the structural portable layout"
                )
            }
            let unsupportedModifiers: Set<String> = ["lazy", "weak", "unowned", "nonisolated"]
            guard !variable.modifiers.contains(where: {
                unsupportedModifiers.contains($0.name.text)
            }) else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "The stored-property ownership or isolation modifier is not portable"
                )
            }
            guard variable.bindings.count == 1,
                  let binding = variable.bindings.first
            else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Portable stored properties must use one declaration per binding"
                )
            }
            if let accessorBlock = binding.accessorBlock {
                let accessors = accessorBlock.trimmedDescription
                guard accessors.contains("willSet") || accessors.contains("didSet") else {
                    otherMembers.append(member.decl.trimmedDescription)
                    continue
                }
            }
            guard !variable.modifiers.contains(where: {
                $0.name.text == "private" || $0.name.text == "fileprivate"
            }) else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Private stored Codable fields are not visible to generated codecs"
                )
            }
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let type = binding.typeAnnotation?.type.trimmedDescription
            else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Stored Codable fields require explicit names and types"
                )
            }
            if variable.bindingSpecifier.tokenKind == .keyword(.let),
               binding.initializer != nil {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Immutable stored fields with defaults are not decoded by synthesized Codable"
                )
            }
            if let defaultExpression = binding.initializer?.value {
                try ActorPortableDefaultExpressionValidator.validate(
                    defaultExpression,
                    symbol: "\(symbol).\(name)",
                    declaration: "Portable stored-field"
                )
            }
            fields.append(
                ActorPortableFieldModel(
                    name: name,
                    type: type,
                    defaultValue: binding.initializer?.value.trimmedDescription,
                    source: variable.trimmedDescription
                )
            )
        }
        return ActorPortableTypeModel(
            moduleName: moduleName,
            sourcePath: sourcePath,
            imports: imports,
            name: structure.name.text,
            accessLevel: structureAccess,
            conformances: portableConformances(structure.inheritanceClause),
            otherMembers: otherMembers,
            kind: .structure(fields: fields)
        )
    }

    fileprivate static func enumerationModel(
        _ enumeration: EnumDeclSyntax,
        moduleName: String,
        sourcePath: String,
        imports: [String]
    ) throws -> ActorPortableTypeModel {
        let symbol = "\(moduleName).\(enumeration.name.text)"
        let enumerationAccess = accessLevel(enumeration.modifiers)
        let allowedEnumModifiers = portableTypeModifierNames.union(["indirect"])
        guard enumeration.attributes.isEmpty,
              enumeration.modifiers.allSatisfy({ allowedEnumModifiers.contains($0.name.text) })
        else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Enum attributes or declaration modifiers cannot be projected identically to Embedded Swift"
            )
        }
        guard enumeration.genericParameterClause == nil,
              enumeration.genericWhereClause == nil else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Generic portable enums are not supported in the first wire profile"
            )
        }
        guard enumerationAccess != "private", enumerationAccess != "fileprivate" else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "A generated portable codec must be able to see its value type"
            )
        }
        try validateEnumerationInheritance(enumeration.inheritanceClause, symbol: symbol)
        for member in enumeration.memberBlock.members {
            if let declaration = member.decl.as(EnumDeclSyntax.self),
               declaration.name.text == "CodingKeys" {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom CodingKeys are outside the structural portable layout"
                )
            }
            if let function = member.decl.as(FunctionDeclSyntax.self),
               isCustomCodableEncoder(function) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom Codable encoding is not portable to Embedded Swift"
                )
            }
            if let initializer = member.decl.as(InitializerDeclSyntax.self),
               isCustomCodableDecoder(initializer) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Custom Codable decoding is not portable to Embedded Swift"
                )
            }
        }
        var cases: [ActorPortableCaseModel] = []
        var otherMembers: [String] = []
        for member in enumeration.memberBlock.members {
            guard let caseDeclaration = member.decl.as(EnumCaseDeclSyntax.self) else {
                otherMembers.append(member.decl.trimmedDescription)
                continue
            }
            guard caseDeclaration.attributes.isEmpty else {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: symbol,
                    reason: "Enum-case attributes are outside the structural portable layout"
                )
            }
            for element in caseDeclaration.elements {
                guard element.rawValue == nil else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: "\(symbol).\(element.name.text)",
                        reason: "Raw-value enums require an exported dependency schema"
                    )
                }
                let values = element.parameterClause?.parameters.map { parameter in
                    ActorPortableCaseValueModel(
                        label: parameter.firstName?.text == "_" ? nil : parameter.firstName?.text,
                        type: parameter.type.trimmedDescription
                    )
                } ?? []
                cases.append(
                    ActorPortableCaseModel(
                        name: element.name.text,
                        associatedValues: values,
                        sourceElement: element.trimmedDescription,
                        isIndirect: enumeration.modifiers.contains(where: {
                            $0.name.text == "indirect"
                        }) || caseDeclaration.modifiers.contains(where: {
                            $0.name.text == "indirect"
                        })
                    )
                )
            }
        }
        guard !cases.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(enumeration.name.text)",
                reason: "A portable enum must declare at least one case"
            )
        }
        return ActorPortableTypeModel(
            moduleName: moduleName,
            sourcePath: sourcePath,
            imports: imports,
            name: enumeration.name.text,
            accessLevel: enumerationAccess,
            conformances: portableConformances(enumeration.inheritanceClause),
            otherMembers: otherMembers,
            kind: .enumeration(cases: cases)
        )
    }

    private static func inheritsCodable(_ clause: InheritanceClauseSyntax?) -> Bool {
        guard let clause else {
            return false
        }
        let inherited = Set(clause.inheritedTypes.map { $0.type.trimmedDescription })
        return inherited.contains("Codable")
            || inherited.contains("Swift.Codable")
            || !inherited.isDisjoint(with: ["Encodable", "Swift.Encodable"])
                && !inherited.isDisjoint(with: ["Decodable", "Swift.Decodable"])
    }

    private static func validateStructureInheritance(
        _ clause: InheritanceClauseSyntax?,
        symbol: String
    ) throws {
        let allowed: Set<String> = [
            "Codable", "Swift.Codable",
            "Encodable", "Swift.Encodable",
            "Decodable", "Swift.Decodable",
            "Sendable", "Swift.Sendable",
            "Error", "Swift.Error",
            "Equatable", "Swift.Equatable",
            "Hashable", "Swift.Hashable",
        ]
        let unsupported = clause?.inheritedTypes
            .map { $0.type.trimmedDescription }
            .filter { !allowed.contains($0) } ?? []
        guard unsupported.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Custom struct conformances cannot be projected identically to Embedded Swift"
            )
        }
    }

    private static func validateEnumerationInheritance(
        _ clause: InheritanceClauseSyntax?,
        symbol: String
    ) throws {
        let allowed: Set<String> = [
            "Codable", "Swift.Codable",
            "Encodable", "Swift.Encodable",
            "Decodable", "Swift.Decodable",
            "Sendable", "Swift.Sendable",
            "Error", "Swift.Error",
            "Equatable", "Swift.Equatable",
            "Hashable", "Swift.Hashable",
            "CaseIterable", "Swift.CaseIterable",
        ]
        let unsupported = clause?.inheritedTypes
            .map { $0.type.trimmedDescription }
            .filter { !allowed.contains($0) } ?? []
        guard unsupported.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Raw-value or custom enum inheritance is not part of the associated-value wire profile"
            )
        }
    }

    private static func portableConformances(
        _ clause: InheritanceClauseSyntax?
    ) -> [String] {
        let removed: Set<String> = [
            "Codable", "Swift.Codable",
            "Encodable", "Swift.Encodable",
            "Decodable", "Swift.Decodable",
        ]
        return clause?.inheritedTypes
            .map { $0.type.trimmedDescription }
            .filter { !removed.contains($0) } ?? []
    }

    private static func isCustomCodableEncoder(
        _ function: FunctionDeclSyntax
    ) -> Bool {
        let parameters = function.signature.parameterClause.parameters
        guard function.name.text == "encode",
              parameters.count == 1,
              let parameter = parameters.first
        else {
            return false
        }
        return parameter.firstName.text == "to"
            && parameter.type.trimmedDescription.contains("Encoder")
    }

    private static func isCustomCodableDecoder(
        _ initializer: InitializerDeclSyntax
    ) -> Bool {
        let parameters = initializer.signature.parameterClause.parameters
        guard parameters.count == 1,
              let parameter = parameters.first
        else {
            return false
        }
        return parameter.firstName.text == "from"
            && parameter.type.trimmedDescription.contains("Decoder")
    }

    private static let portableTypeModifierNames: Set<String> = [
        "open", "public", "package", "internal", "fileprivate", "private",
    ]

    private static func accessLevel(_ modifiers: DeclModifierListSyntax) -> String {
        for level in ["open", "public", "package", "internal", "fileprivate", "private"]
        where modifiers.contains(where: { $0.name.text == level }) {
            return level
        }
        return "internal"
    }

    private static func sourceImports(in source: SourceFileSyntax) -> [String] {
        var modules = Set<String>()
        func collectImports(from syntax: Syntax) {
            if let importDeclaration = syntax.as(ImportDeclSyntax.self),
               let module = importDeclaration.path.trimmedDescription
                .split(separator: ".")
                .first {
                modules.insert(String(module))
            }
            for child in syntax.children(viewMode: .sourceAccurate) {
                collectImports(from: child)
            }
        }
        collectImports(from: Syntax(source))
        return modules.sorted()
    }

    private static func activeSource(
        _ source: SourceFileSyntax,
        sourceURL: URL,
        targetEnvironment: ActorGenerationTargetEnvironment?
    ) throws -> SourceFileSyntax {
        guard let targetEnvironment else {
            try ActorProfileConditionResolver.validateNoUnresolvedConditions(
                in: source,
                symbol: sourceURL.path
            )
            return source
        }
        return try ActorProfileConditionResolver.activeSource(
            source,
            environment: targetEnvironment,
            symbol: sourceURL.path
        )
    }
}

private enum PortableTypeCandidate {
    case structure(
        StructDeclSyntax,
        moduleName: String,
        sourcePath: String,
        imports: [String]
    )
    case enumeration(
        EnumDeclSyntax,
        moduleName: String,
        sourcePath: String,
        imports: [String]
    )

    var name: String {
        switch self {
        case .structure(let declaration, _, _, _): declaration.name.text
        case .enumeration(let declaration, _, _, _): declaration.name.text
        }
    }

    var symbol: String {
        switch self {
        case .structure(_, let moduleName, _, _),
             .enumeration(_, let moduleName, _, _):
            "\(moduleName).\(name)"
        }
    }

    var model: ActorPortableTypeModel {
        get throws {
            switch self {
            case .structure(let declaration, let moduleName, let sourcePath, let imports):
                try ActorPortableTypeScanner.structureModel(
                    declaration,
                    moduleName: moduleName,
                    sourcePath: sourcePath,
                    imports: imports
                )
            case .enumeration(let declaration, let moduleName, let sourcePath, let imports):
                try ActorPortableTypeScanner.enumerationModel(
                    declaration,
                    moduleName: moduleName,
                    sourcePath: sourcePath,
                    imports: imports
                )
            }
        }
    }
}
