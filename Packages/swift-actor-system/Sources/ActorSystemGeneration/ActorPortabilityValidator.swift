import SwiftParser
import SwiftSyntax

public enum ActorPortabilityValidator {
    public static func validate(
        actors: [ActorSourceModel],
        portableTypes: [ActorPortableTypeModel],
        dependencySchemas: [ActorSchemaLock]
    ) throws {
        try ActorMethodEffectValidator.validatePortableActorContract(actors)
        let localTypes = Set(portableTypes.flatMap { [$0.name, $0.symbol] })
        let dependencyTypes = Set(
            dependencySchemas.flatMap { schema in
                schema.valueTypes.flatMap { [$0.sourceType, $0.canonicalType] }
            }
        )
        for actor in actors {
            for method in actor.methods {
                for parameter in method.parameters {
                    try validate(
                        parameter.type,
                        symbol: "\(actor.symbol).\(method.name)",
                        localTypes: localTypes,
                        dependencyTypes: dependencyTypes
                    )
                }
                if !isVoid(method.returnType) {
                    try validate(
                        method.returnType,
                        symbol: "\(actor.symbol).\(method.name)",
                        localTypes: localTypes,
                        dependencyTypes: dependencyTypes
                    )
                }
                if let errorType = typedErrorType(method.throwsClause) {
                    try validate(
                        errorType,
                        symbol: "\(actor.symbol).\(method.name)",
                        localTypes: localTypes,
                        dependencyTypes: dependencyTypes
                    )
                }
            }
        }
    }

    private static func validate(
        _ sourceType: String,
        symbol: String,
        localTypes: Set<String>,
        dependencyTypes: Set<String>
    ) throws {
        let source = Parser.parse(
            source: "typealias __ActorPortableType = \(sourceType)"
        )
        guard let statement = source.statements.first,
              case .decl(let declaration) = statement.item,
              let alias = declaration.as(TypeAliasDeclSyntax.self)
        else {
            throw unsupported(sourceType, symbol: symbol)
        }
        try validate(
            alias.initializer.value,
            sourceType: sourceType,
            symbol: symbol,
            localTypes: localTypes,
            dependencyTypes: dependencyTypes
        )
    }

    private static func validate(
        _ type: TypeSyntax,
        sourceType: String,
        symbol: String,
        localTypes: Set<String>,
        dependencyTypes: Set<String>
    ) throws {
        if let optional = type.as(OptionalTypeSyntax.self) {
            try validate(
                optional.wrappedType,
                sourceType: sourceType,
                symbol: symbol,
                localTypes: localTypes,
                dependencyTypes: dependencyTypes
            )
            return
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            try validate(
                array.element,
                sourceType: sourceType,
                symbol: symbol,
                localTypes: localTypes,
                dependencyTypes: dependencyTypes
            )
            return
        }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            try validate(
                dictionary.key,
                sourceType: sourceType,
                symbol: symbol,
                localTypes: localTypes,
                dependencyTypes: dependencyTypes
            )
            try validate(
                dictionary.value,
                sourceType: sourceType,
                symbol: symbol,
                localTypes: localTypes,
                dependencyTypes: dependencyTypes
            )
            return
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            let name = identifier.name.text
            let arguments: [TypeSyntax]
            if let genericArguments = identifier.genericArgumentClause?.arguments {
                arguments = try genericArguments.map { argument in
                    guard case .type(let type) = argument.argument else {
                        throw unsupported(sourceType, symbol: symbol)
                    }
                    return type
                }
            } else {
                arguments = []
            }
            switch name {
            case "Optional", "Array":
                guard arguments.count == 1 else {
                    throw unsupported(sourceType, symbol: symbol)
                }
            case "Dictionary":
                guard arguments.count == 2 else {
                    throw unsupported(sourceType, symbol: symbol)
                }
            default:
                guard arguments.isEmpty,
                      isKnown(
                        name,
                        localTypes: localTypes,
                        dependencyTypes: dependencyTypes
                      )
                else {
                    throw unsupported(sourceType, symbol: symbol)
                }
            }
            for argument in arguments {
                try validate(
                    argument,
                    sourceType: sourceType,
                    symbol: symbol,
                    localTypes: localTypes,
                    dependencyTypes: dependencyTypes
                )
            }
            return
        }
        if let member = type.as(MemberTypeSyntax.self) {
            let qualified = member.trimmedDescription
            guard member.genericArgumentClause == nil,
                  isKnown(
                    qualified,
                    localTypes: localTypes,
                    dependencyTypes: dependencyTypes
                  )
            else {
                throw unsupported(sourceType, symbol: symbol)
            }
            return
        }
        throw unsupported(sourceType, symbol: symbol)
    }

    private static func isKnown(
        _ type: String,
        localTypes: Set<String>,
        dependencyTypes: Set<String>
    ) -> Bool {
        let leaf = type.split(separator: ".").last.map(String.init) ?? type
        if portableBuiltins.contains(leaf),
           !type.contains(".") || type.hasPrefix("Swift.") {
            return true
        }
        return localTypes.contains(type)
            || dependencyTypes.contains(type)
            || (!type.contains(".") && localTypes.contains(where: { $0.hasSuffix(".\(type)") }))
            || (!type.contains(".") && dependencyTypes.contains(where: { $0.hasSuffix(".\(type)") }))
    }

    private static func unsupported(
        _ sourceType: String,
        symbol: String
    ) -> ActorGenerationError {
        ActorGenerationError.unsupportedDeclaration(
            symbol: symbol,
            reason: "\(sourceType) is outside the portable value set or has no exported actor schema"
        )
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

    private static let portableBuiltins: Set<String> = [
        "Bool", "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Float", "Double",
        "String", "ActorByteBuffer",
    ]
}
