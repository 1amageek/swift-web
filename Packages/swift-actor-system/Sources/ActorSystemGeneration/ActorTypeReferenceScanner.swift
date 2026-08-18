import SwiftParser
import SwiftSyntax

enum ActorTypeReferenceScanner {
    static func references(in sourceType: String) throws -> Set<String> {
        let source = Parser.parse(
            source: "typealias __ActorSystemType = \(sourceType)"
        )
        guard let statement = source.statements.first,
              case .decl(let declaration) = statement.item,
              let alias = declaration.as(TypeAliasDeclSyntax.self)
        else {
            throw ActorGenerationError.schemaConflict(
                reason: "Cannot parse portable type reference \(sourceType)"
            )
        }
        var references: Set<String> = []
        collect(alias.initializer.value, into: &references)
        return references
    }

    private static func collect(
        _ type: TypeSyntax,
        into references: inout Set<String>
    ) {
        references.insert(type.trimmedDescription)
        if let optional = type.as(OptionalTypeSyntax.self) {
            collect(optional.wrappedType, into: &references)
            return
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            collect(array.element, into: &references)
            return
        }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            collect(dictionary.key, into: &references)
            collect(dictionary.value, into: &references)
            return
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            if let arguments = identifier.genericArgumentClause?.arguments {
                for argument in arguments {
                    guard case .type(let argumentType) = argument.argument else {
                        continue
                    }
                    collect(argumentType, into: &references)
                }
            }
            return
        }
        if let member = type.as(MemberTypeSyntax.self) {
            if let arguments = member.genericArgumentClause?.arguments {
                for argument in arguments {
                    guard case .type(let argumentType) = argument.argument else {
                        continue
                    }
                    collect(argumentType, into: &references)
                }
            }
        }
    }
}
