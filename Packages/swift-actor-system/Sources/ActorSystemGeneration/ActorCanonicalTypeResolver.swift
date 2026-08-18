import SwiftParser
import SwiftSyntax

struct ActorCanonicalTypeResolver {
    private let localTypes: [ActorPortableTypeModel]
    private let dependencyTypes: [ActorSchemaLockValueType]

    init(
        localTypes: [ActorPortableTypeModel],
        dependencyTypes: [ActorSchemaLockValueType]
    ) {
        self.localTypes = localTypes
        self.dependencyTypes = dependencyTypes
    }

    func canonicalType(for sourceType: String) throws -> String {
        let source = Parser.parse(
            source: "typealias __ActorCanonicalType = \(sourceType)"
        )
        guard let statement = source.statements.first,
              case .decl(let declaration) = statement.item,
              let alias = declaration.as(TypeAliasDeclSyntax.self)
        else {
            throw ActorGenerationError.schemaConflict(
                reason: "Cannot parse portable type reference \(sourceType)"
            )
        }
        return try canonicalType(for: alias.initializer.value)
    }

    private func canonicalType(for type: TypeSyntax) throws -> String {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return "Swift.Optional<\(try canonicalType(for: optional.wrappedType))>"
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return "Swift.Array<\(try canonicalType(for: array.element))>"
        }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            return "Swift.Dictionary<\(try canonicalType(for: dictionary.key)),\(try canonicalType(for: dictionary.value))>"
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            let name = identifier.name.text
            let arguments: [TypeSyntax]
            if let genericArguments = identifier.genericArgumentClause?.arguments {
                arguments = try genericArguments.map { argument in
                    guard case .type(let argumentType) = argument.argument else {
                        throw unsupported(type)
                    }
                    return argumentType
                }
            } else {
                arguments = []
            }
            switch name {
            case "Optional", "Array":
                guard arguments.count == 1, let argument = arguments.first else {
                    throw unsupported(type)
                }
                return "Swift.\(name)<\(try canonicalType(for: argument))>"
            case "Dictionary":
                guard arguments.count == 2 else {
                    throw unsupported(type)
                }
                return "Swift.Dictionary<\(try canonicalType(for: arguments[0])),\(try canonicalType(for: arguments[1]))>"
            default:
                guard arguments.isEmpty else {
                    throw unsupported(type)
                }
                return try canonicalNamedType(name)
            }
        }
        if let member = type.as(MemberTypeSyntax.self),
           member.genericArgumentClause == nil {
            return try canonicalNamedType(member.trimmedDescription)
        }
        throw unsupported(type)
    }

    private func canonicalNamedType(_ sourceName: String) throws -> String {
        let leaf = sourceName.split(separator: ".").last.map(String.init) ?? sourceName
        if Self.swiftBuiltins.contains(leaf),
           !sourceName.contains(".") || sourceName.hasPrefix("Swift.") {
            return "Swift.\(leaf)"
        }
        if leaf == "ActorByteBuffer",
           !sourceName.contains(".") || sourceName == "ActorSystemCore.ActorByteBuffer" {
            return "ActorSystemCore.ActorByteBuffer"
        }
        if let local = localTypes.first(where: {
            $0.symbol == sourceName || $0.name == sourceName
        }) {
            return local.symbol
        }
        let exactDependencies = dependencyTypes.filter {
            $0.canonicalType == sourceName || $0.sourceType == sourceName
        }
        if exactDependencies.count == 1, let dependency = exactDependencies.first {
            return dependency.canonicalType
        }
        guard !sourceName.contains(".") else {
            throw unsupportedName(sourceName)
        }
        let dependencyMatches = dependencyTypes.filter {
            $0.canonicalType.split(separator: ".").last.map(String.init) == sourceName
                || $0.sourceType.split(separator: ".").last.map(String.init) == sourceName
        }
        guard dependencyMatches.count == 1,
              let dependency = dependencyMatches.first
        else {
            if dependencyMatches.count > 1 {
                throw ActorGenerationError.schemaConflict(
                    reason: "Portable type \(sourceName) is ambiguous across dependency schemas"
                )
            }
            throw unsupportedName(sourceName)
        }
        return dependency.canonicalType
    }

    private func unsupported(_ type: TypeSyntax) -> ActorGenerationError {
        unsupportedName(type.trimmedDescription)
    }

    private func unsupportedName(_ name: String) -> ActorGenerationError {
        ActorGenerationError.unsupportedDeclaration(
            symbol: name,
            reason: "The type has no canonical portable schema identity"
        )
    }

    private static let swiftBuiltins: Set<String> = [
        "Bool", "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Float", "Double", "String",
    ]
}
