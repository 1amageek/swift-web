import Foundation
import SwiftParser
import SwiftSyntax

public enum ActorSourceScanner {
    public static func scan(
        sourceFiles: [URL],
        moduleName: String,
        includingActorSystemTypes: Set<String>? = nil,
        includingActorSymbols: Set<String>? = nil,
        targetEnvironment: ActorGenerationTargetEnvironment? = nil
    ) throws -> [ActorSourceModel] {
        var actors: [ActorSourceModel] = []
        for sourceURL in sourceFiles.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let originalSyntax = Parser.parse(source: source)
            try ActorConditionalCompilationValidator.validateActorSource(
                originalSyntax,
                moduleName: moduleName,
                actorSystemTypes: includingActorSystemTypes,
                actorSymbols: includingActorSymbols
            )
            let syntax = try activeSource(
                originalSyntax,
                sourceURL: sourceURL,
                targetEnvironment: targetEnvironment
            )
            let imports = sourceImports(in: syntax)
            for statement in syntax.statements {
                guard case .decl(let declaration) = statement.item,
                      let actor = declaration.as(ActorDeclSyntax.self),
                      hasModifier("distributed", in: actor.modifiers),
                      includesActor(
                        actor,
                        moduleName: moduleName,
                        actorSystemTypes: includingActorSystemTypes,
                        actorSymbols: includingActorSymbols
                      )
                else {
                    continue
                }
                actors.append(
                    try model(
                        actor,
                        moduleName: moduleName,
                        sourcePath: sourceURL.path,
                        imports: imports
                    )
                )
            }
        }
        let actorNames = Set(actors.map(\.name))
        for sourceURL in sourceFiles.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let syntax = try activeSource(
                Parser.parse(source: source),
                sourceURL: sourceURL,
                targetEnvironment: targetEnvironment
            )
            for statement in syntax.statements {
                guard case .decl(let declaration) = statement.item,
                      let actorExtension = declaration.as(ExtensionDeclSyntax.self),
                      let actorName = actorExtension.extendedType.trimmedDescription
                        .split(separator: ".").last.map(String.init),
                      actorNames.contains(actorName)
                else {
                    continue
                }
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(moduleName).\(actorName)",
                    reason: "Portable distributed actor members must be declared in the actor body, not an extension"
                )
            }
        }
        return actors.sorted { $0.symbol < $1.symbol }
    }

    private static func model(
        _ actor: ActorDeclSyntax,
        moduleName: String,
        sourcePath: String,
        imports: [String]
    ) throws -> ActorSourceModel {
        guard actor.attributes.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "Actor attributes cannot be projected identically to every target"
            )
        }
        let allowedActorModifiers: Set<String> = [
            "distributed", "open", "public", "package", "internal", "fileprivate", "private",
        ]
        guard actor.modifiers.allSatisfy({ allowedActorModifiers.contains($0.name.text) }) else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "The actor declaration contains a modifier that cannot be projected"
            )
        }
        guard actor.genericParameterClause == nil else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "Generic distributed actors are not portable"
            )
        }
        guard actor.inheritanceClause == nil else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "Explicit actor conformances cannot be projected to every target"
            )
        }
        let actorAccess = accessLevel(actor.modifiers)
        guard actorAccess != "private", actorAccess != "fileprivate" else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "A generated actor descriptor must be visible outside its source file"
            )
        }

        var properties: [ActorStoredPropertyModel] = []
        var initializers: [ActorInitializerModel] = []
        var methods: [ActorMethodModel] = []
        var otherMembers: [String] = []

        for member in actor.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self),
               hasModifier("distributed", in: function.modifiers) {
                let allowedMethodModifiers: Set<String> = [
                    "distributed", "open", "public", "package", "internal", "fileprivate", "private",
                ]
                guard function.genericParameterClause == nil,
                      function.genericWhereClause == nil,
                      function.body != nil,
                      function.attributes.isEmpty,
                      function.modifiers.allSatisfy({ allowedMethodModifiers.contains($0.name.text) })
                else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: "\(moduleName).\(actor.name.text).\(function.name.text)",
                        reason: "Generic distributed methods are not portable"
                    )
                }
                try validateParameters(
                    function.signature.parameterClause.parameters,
                    symbol: "\(moduleName).\(actor.name.text).\(function.name.text)",
                    declaration: "Distributed method"
                )
                methods.append(methodModel(function))
                continue
            }
            if let initializer = member.decl.as(InitializerDeclSyntax.self) {
                let allowedInitializerModifiers: Set<String> = [
                    "open", "public", "package", "internal", "fileprivate", "private",
                ]
                guard initializer.optionalMark == nil,
                      initializer.genericParameterClause == nil,
                      initializer.genericWhereClause == nil,
                      initializer.body != nil,
                      initializer.attributes.isEmpty,
                      initializer.modifiers.allSatisfy({
                          allowedInitializerModifiers.contains($0.name.text)
                      })
                else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: "\(moduleName).\(actor.name.text)",
                        reason: "Failable or generic actor initializers cannot be projected to an Embedded actor twin"
                    )
                }
                try validateParameters(
                    initializer.signature.parameterClause.parameters,
                    symbol: "\(moduleName).\(actor.name.text)",
                    declaration: "Actor initializer"
                )
                initializers.append(initializerModel(initializer))
                continue
            }
            if let variable = member.decl.as(VariableDeclSyntax.self),
               !hasModifier("static", in: variable.modifiers),
               !hasModifier("class", in: variable.modifiers) {
                guard variable.bindings.count == 1,
                      let binding = variable.bindings.first
                else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: "\(moduleName).\(actor.name.text)",
                        reason: "Actor stored properties must use one declaration per binding"
                    )
                }
                let containsComputedBinding = variable.bindings.contains { binding in
                    guard let accessorBlock = binding.accessorBlock else {
                        return false
                    }
                    let accessors = accessorBlock.trimmedDescription
                    return !accessors.contains("willSet") && !accessors.contains("didSet")
                }
                if containsComputedBinding {
                    otherMembers.append(member.decl.trimmedDescription)
                    continue
                }
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      let type = binding.typeAnnotation?.type.trimmedDescription
                else {
                    throw ActorGenerationError.unsupportedDeclaration(
                        symbol: "\(moduleName).\(actor.name.text)",
                        reason: "Actor stored properties require explicit names and types"
                    )
                }
                let accessors = binding.accessorBlock?.trimmedDescription ?? ""
                properties.append(
                    ActorStoredPropertyModel(
                        name: name,
                        type: type,
                        source: variable.trimmedDescription,
                        modifiers: variable.modifiers.map { $0.name.text },
                        accessLevel: accessLevel(variable.modifiers),
                        isImmutable: variable.bindingSpecifier.tokenKind == .keyword(.let),
                        hasAttributes: !variable.attributes.isEmpty,
                        hasObservers: accessors.contains("willSet") || accessors.contains("didSet"),
                        hasInitialValue: binding.initializer != nil,
                        initialValue: binding.initializer?.value.trimmedDescription
                    )
                )
                continue
            }
            if let typeAlias = member.decl.as(TypeAliasDeclSyntax.self) {
                if typeAlias.name.text != "ActorSystem" {
                    otherMembers.append(member.decl.trimmedDescription)
                }
                continue
            }
            otherMembers.append(member.decl.trimmedDescription)
        }

        guard !methods.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: "\(moduleName).\(actor.name.text)",
                reason: "A portable actor must declare at least one distributed method"
            )
        }
        return ActorSourceModel(
            moduleName: moduleName,
            sourcePath: sourcePath,
            imports: imports,
            name: actor.name.text,
            accessLevel: actorAccess,
            storedProperties: properties,
            initializers: initializers,
            methods: methods,
            otherMembers: otherMembers
        )
    }

    private static func methodModel(_ function: FunctionDeclSyntax) -> ActorMethodModel {
        ActorMethodModel(
            name: function.name.text,
            parameters: parameters(function.signature.parameterClause.parameters),
            returnType: function.signature.returnClause?.type.trimmedDescription ?? "Void",
            isAsync: function.signature.effectSpecifiers?.asyncSpecifier != nil,
            throwsClause: function.signature.effectSpecifiers?.throwsClause?.trimmedDescription,
            body: function.body?.statements.trimmedDescription ?? "",
            accessLevel: accessLevel(function.modifiers)
        )
    }

    private static func initializerModel(_ initializer: InitializerDeclSyntax) -> ActorInitializerModel {
        ActorInitializerModel(
            parameters: parameters(initializer.signature.parameterClause.parameters),
            effects: initializer.signature.effectSpecifiers?.trimmedDescription ?? "",
            body: initializer.body?.statements.trimmedDescription ?? "",
            bodyStatements: initializer.body?.statements.map(\.trimmedDescription) ?? [],
            accessLevel: accessLevel(initializer.modifiers)
        )
    }

    private static func parameters(
        _ parameters: FunctionParameterListSyntax
    ) -> [ActorParameterModel] {
        parameters.map { parameter in
            ActorParameterModel(
                externalName: parameter.firstName.text,
                localName: parameter.secondName?.text ?? parameter.firstName.text,
                type: parameter.type.trimmedDescription,
                defaultValue: parameter.defaultValue?.value.trimmedDescription
            )
        }
    }

    private static func validateParameters(
        _ parameters: FunctionParameterListSyntax,
        symbol: String,
        declaration: String
    ) throws {
        guard parameters.allSatisfy({ parameter in
            parameter.attributes.isEmpty
                && parameter.modifiers.isEmpty
                && parameter.ellipsis == nil
        }) else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "\(declaration) parameter attributes, modifiers, and variadics cannot be projected identically"
            )
        }
        for parameter in parameters {
            guard let defaultExpression = parameter.defaultValue?.value else {
                continue
            }
            try ActorPortableDefaultExpressionValidator.validate(
                defaultExpression,
                symbol: symbol,
                declaration: "\(declaration) parameter"
            )
        }
    }

    private static func accessLevel(_ modifiers: DeclModifierListSyntax) -> String {
        for level in ["open", "public", "package", "internal", "fileprivate", "private"]
        where hasModifier(level, in: modifiers) {
            return level
        }
        return "internal"
    }

    private static func hasModifier(
        _ name: String,
        in modifiers: DeclModifierListSyntax
    ) -> Bool {
        modifiers.contains { $0.name.text == name }
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
            return actorSystemTypes.contains(
                typeAlias.initializer.value.trimmedDescription
            )
        }
        return false
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
