import SwiftSyntax

enum ActorConditionalCompilationValidator {
    static func validateActorSource(
        _ source: SourceFileSyntax,
        moduleName: String,
        actorSystemTypes: Set<String>?,
        actorSymbols: Set<String>?
    ) throws {
        try walk(Syntax(source), insideConditionalCompilation: false) { declaration in
            guard let actor = declaration.as(ActorDeclSyntax.self),
                  actor.modifiers.contains(where: { $0.name.text == "distributed" }),
                  includesActor(
                    actor,
                    moduleName: moduleName,
                    actorSystemTypes: actorSystemTypes,
                    actorSymbols: actorSymbols
                  )
            else {
                return
            }
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "Portable distributed actors cannot be declared inside conditional compilation"
            )
        }
    }

    static func validatePortableValueSource(
        _ source: SourceFileSyntax,
        moduleName: String
    ) throws {
        try walk(Syntax(source), insideConditionalCompilation: false) { declaration in
            if let structure = declaration.as(StructDeclSyntax.self),
               inheritsCodable(structure.inheritanceClause) {
                throw conditionalPortableValueError(
                    moduleName: moduleName,
                    name: structure.name.text
                )
            }
            if let enumeration = declaration.as(EnumDeclSyntax.self),
               inheritsCodable(enumeration.inheritanceClause) {
                throw conditionalPortableValueError(
                    moduleName: moduleName,
                    name: enumeration.name.text
                )
            }
        }
    }

    static func validateProjectionSource(
        _ source: SourceFileSyntax,
        input: ActorGeneratedManifest.InputSource,
        profile: ActorGenerationProfile
    ) throws {
        let actorNames = Set(input.replacedActorNames)
        let portableTypeNames = Set(input.replacedPortableTypeNames)
        _ = profile
        try walk(Syntax(source), insideConditionalCompilation: false) { declaration in
            if let actor = declaration.as(ActorDeclSyntax.self),
               actorNames.contains(actor.name.text) {
                throw conditionalProjectionError(input.relativePath)
            }
            if let structure = declaration.as(StructDeclSyntax.self),
               portableTypeNames.contains(structure.name.text) {
                throw conditionalProjectionError(input.relativePath)
            }
            if let enumeration = declaration.as(EnumDeclSyntax.self),
               portableTypeNames.contains(enumeration.name.text) {
                throw conditionalProjectionError(input.relativePath)
            }
            if let actorExtension = declaration.as(ExtensionDeclSyntax.self),
               let actorName = actorExtension.extendedType.trimmedDescription
                .split(separator: ".").last.map(String.init),
               actorNames.contains(actorName) {
                throw conditionalProjectionError(input.relativePath)
            }
        }
    }

    private static func walk(
        _ syntax: Syntax,
        insideConditionalCompilation: Bool,
        body: (DeclSyntax) throws -> Void
    ) throws {
        let isConditional = syntax.as(IfConfigDeclSyntax.self) != nil
        let nestedInsideConditionalCompilation = insideConditionalCompilation || isConditional
        if insideConditionalCompilation,
           let declaration = syntax.as(DeclSyntax.self) {
            try body(declaration)
        }
        for child in syntax.children(viewMode: .sourceAccurate) {
            try walk(
                child,
                insideConditionalCompilation: nestedInsideConditionalCompilation,
                body: body
            )
        }
    }

    private static func includesActor(
        _ actor: ActorDeclSyntax,
        moduleName: String,
        actorSystemTypes: Set<String>?,
        actorSymbols: Set<String>?
    ) -> Bool {
        if let actorSymbols,
           !actorSymbols.contains("\(moduleName).\(actor.name.text)") {
            return false
        }
        guard let actorSystemTypes else {
            return true
        }
        for member in actor.memberBlock.members {
            guard let typeAlias = member.decl.as(TypeAliasDeclSyntax.self),
                  typeAlias.name.text == "ActorSystem"
            else {
                continue
            }
            return actorSystemTypes.contains(typeAlias.initializer.value.trimmedDescription)
        }
        return false
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

    static func inheritsEmbeddedUnsupportedSerialization(
        _ clause: InheritanceClauseSyntax?
    ) -> Bool {
        guard let clause else {
            return false
        }
        let inherited = Set(clause.inheritedTypes.map { $0.type.trimmedDescription })
        return !inherited.isDisjoint(with: [
            "Codable", "Swift.Codable",
            "Encodable", "Swift.Encodable",
            "Decodable", "Swift.Decodable",
        ])
    }

    private static func conditionalPortableValueError(
        moduleName: String,
        name: String
    ) -> ActorGenerationError {
        .unsupportedDeclaration(
            symbol: "\(moduleName).\(name)",
            reason: "Portable Codable values cannot be declared inside conditional compilation"
        )
    }

    private static func conditionalProjectionError(
        _ sourcePath: String
    ) -> ActorGenerationError {
        .unsupportedDeclaration(
            symbol: sourcePath,
            reason: "Generated actor declarations cannot be projected from conditional compilation"
        )
    }
}
