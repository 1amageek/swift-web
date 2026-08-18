import Foundation
import SwiftParser
import SwiftSyntax

public enum ActorSourceProjector {
    public static func project(
        source: String,
        input: ActorGeneratedManifest.InputSource,
        profile: ActorGenerationProfile,
        targetEnvironment: ActorGenerationTargetEnvironment
    ) throws -> String {
        guard ActorStableHash.digest(source) == input.contentDigest else {
            throw ActorGenerationError.schemaConflict(
                reason: "Source content changed after actor generation for \(input.relativePath)"
            )
        }
        guard profile != .nativeHost else {
            return source
        }

        let actors = Set(input.replacedActorNames)
        let portableTypes = Set(input.replacedPortableTypeNames)
        let originalSyntax = Parser.parse(source: source)
        try ActorConditionalCompilationValidator.validateProjectionSource(
            originalSyntax,
            input: input,
            profile: profile
        )
        let syntax = try ActorProfileConditionResolver.activeSource(
            originalSyntax,
            environment: targetEnvironment,
            symbol: input.relativePath
        )
        var projected: [String] = []
        var unresolvedDroppedImports: [String] = []
        var hasPreservedNonImportContent = false
        for statement in syntax.statements {
            guard case .decl(let declaration) = statement.item else {
                projected.append(statement.description)
                if !statement.trimmedDescription.isEmpty {
                    hasPreservedNonImportContent = true
                }
                continue
            }
            if let importDeclaration = declaration.as(ImportDeclSyntax.self),
               let module = importDeclaration.path.trimmedDescription
                .split(separator: ".")
                .first.map(String.init) {
                let isEmbedded = profile == .embeddedHost
                    || profile == .embeddedClient
                let embeddedUnsupported = isEmbedded && [
                    "Distributed", "ActorSystemDistributed",
                ].contains(module)
                let clientUnsupported = !targetEnvironment.availableModules.contains(module)
                if embeddedUnsupported || clientUnsupported {
                    if !embeddedUnsupported {
                        unresolvedDroppedImports.append(module)
                    }
                    continue
                }
                projected.append(statement.description)
                continue
            }
            if let actor = declaration.as(ActorDeclSyntax.self),
               actors.contains(actor.name.text) {
                continue
            }
            if profile == .standardClient || profile == .embeddedClient,
               let actorExtension = declaration.as(ExtensionDeclSyntax.self),
               let actorName = extendedTypeLeafName(actorExtension.extendedType),
               actors.contains(actorName) {
                continue
            }
            if let structure = declaration.as(StructDeclSyntax.self),
               portableTypes.contains(structure.name.text) {
                continue
            }
            if let enumeration = declaration.as(EnumDeclSyntax.self),
               portableTypes.contains(enumeration.name.text) {
                continue
            }
            projected.append(statement.description)
            hasPreservedNonImportContent = true
        }
        if hasPreservedNonImportContent,
           !unresolvedDroppedImports.isEmpty {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: input.relativePath,
                reason: "Client projection cannot retain declarations beside unavailable imports: \(Array(Set(unresolvedDroppedImports)).sorted().joined(separator: ", "))"
            )
        }
        let result = projected.joined()
        try validateProjection(
            result,
            input: input,
            profile: profile
        )
        return result
    }

    private static func validateProjection(
        _ source: String,
        input: ActorGeneratedManifest.InputSource,
        profile: ActorGenerationProfile
    ) throws {
        let syntax = Parser.parse(source: source)
        let actorNames = Set(input.replacedActorNames)
        let portableTypeNames = Set(input.replacedPortableTypeNames)
        if profile == .embeddedHost || profile == .embeddedClient {
            try validateEmbeddedProjection(Syntax(syntax), input: input)
        }
        for statement in syntax.statements {
            guard case .decl(let declaration) = statement.item else {
                continue
            }
            if let actor = declaration.as(ActorDeclSyntax.self),
               actorNames.contains(actor.name.text) {
                throw ActorGenerationError.schemaConflict(
                    reason: "Projected source still contains actor \(actor.name.text)"
                )
            }
            if profile == .standardClient || profile == .embeddedClient,
               let actorExtension = declaration.as(ExtensionDeclSyntax.self),
               let actorName = extendedTypeLeafName(actorExtension.extendedType),
               actorNames.contains(actorName) {
                throw ActorGenerationError.schemaConflict(
                    reason: "Projected client source still contains an extension of actor \(actorName)"
                )
            }
            if let structure = declaration.as(StructDeclSyntax.self),
               portableTypeNames.contains(structure.name.text) {
                throw ActorGenerationError.schemaConflict(
                    reason: "Projected source still contains portable value \(structure.name.text)"
                )
            }
            if let enumeration = declaration.as(EnumDeclSyntax.self),
               portableTypeNames.contains(enumeration.name.text) {
                throw ActorGenerationError.schemaConflict(
                    reason: "Projected source still contains portable value \(enumeration.name.text)"
                )
            }
        }
    }

    private static func validateEmbeddedProjection(
        _ syntax: Syntax,
        input: ActorGeneratedManifest.InputSource
    ) throws {
        if let importDeclaration = syntax.as(ImportDeclSyntax.self),
           let module = importDeclaration.path.trimmedDescription
            .split(separator: ".").first.map(String.init),
           [
            "Distributed", "ActorSystemDistributed",
           ].contains(module) {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: input.relativePath,
                reason: "Embedded projection contains unsupported import \(module)"
            )
        }
        if let actor = syntax.as(ActorDeclSyntax.self),
           actor.modifiers.contains(where: { $0.name.text == "distributed" }) {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: actor.name.text,
                reason: "Embedded projection contains an ungenerated distributed actor"
            )
        }
        if let conformance = embeddedSerializationConformance(in: syntax),
           ActorConditionalCompilationValidator.inheritsEmbeddedUnsupportedSerialization(
            conformance.clause
           ) {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: conformance.name,
                reason: "Embedded projection contains an unsupported Codable conformance"
            )
        }
        for child in syntax.children(viewMode: .sourceAccurate) {
            try validateEmbeddedProjection(child, input: input)
        }
    }

    private static func embeddedSerializationConformance(
        in syntax: Syntax
    ) -> (name: String, clause: InheritanceClauseSyntax?)? {
        if let structure = syntax.as(StructDeclSyntax.self) {
            return (structure.name.text, structure.inheritanceClause)
        }
        if let enumeration = syntax.as(EnumDeclSyntax.self) {
            return (enumeration.name.text, enumeration.inheritanceClause)
        }
        if let classDeclaration = syntax.as(ClassDeclSyntax.self) {
            return (classDeclaration.name.text, classDeclaration.inheritanceClause)
        }
        if let protocolDeclaration = syntax.as(ProtocolDeclSyntax.self) {
            return (protocolDeclaration.name.text, protocolDeclaration.inheritanceClause)
        }
        if let actorDeclaration = syntax.as(ActorDeclSyntax.self) {
            return (actorDeclaration.name.text, actorDeclaration.inheritanceClause)
        }
        if let extensionDeclaration = syntax.as(ExtensionDeclSyntax.self) {
            return (
                extensionDeclaration.extendedType.trimmedDescription,
                extensionDeclaration.inheritanceClause
            )
        }
        return nil
    }

    private static func extendedTypeLeafName(_ type: TypeSyntax) -> String? {
        type.trimmedDescription.split(separator: ".").last.map(String.init)
    }
}
