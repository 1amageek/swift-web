import Foundation
import SwiftParser
import SwiftSyntax

/// Discovers app-defined `ClientEnvironmentKey` conformances so the generated
/// WASM entrypoint can extend `ClientEnvironmentRegistry.swiftWebUI` with
/// them. Without registration, hydration aborts with `missingDecoder` for any
/// scene- or request-provided value whose key the framework does not know.
///
/// Only `public` top-level declarations are collected: the generated
/// entrypoint lives in a separate target (and package), so other access
/// levels cannot be referenced from it. A non-public key still fails loudly
/// at hydration through the registry's `missingDecoder` error.
struct SwiftWebClientEnvironmentKeyDiscovery {
    static func discover(
        in swiftFiles: [(url: URL, relativePath: String)]
    ) throws -> [String] {
        var typeNames: Set<String> = []
        for file in swiftFiles {
            let source = try String(contentsOf: file.url, encoding: .utf8)
            let syntax = Parser.parse(source: source)
            for statement in syntax.statements {
                collect(topLevel: Syntax(statement.item), into: &typeNames)
            }
        }
        return typeNames.sorted()
    }

    private static func collect(topLevel node: Syntax, into typeNames: inout Set<String>) {
        if let declaration = node.as(StructDeclSyntax.self),
           isPublic(declaration.modifiers),
           inheritsClientEnvironmentKey(declaration.inheritanceClause)
        {
            typeNames.insert(declaration.name.text)
        }

        if let declaration = node.as(EnumDeclSyntax.self),
           isPublic(declaration.modifiers),
           inheritsClientEnvironmentKey(declaration.inheritanceClause)
        {
            typeNames.insert(declaration.name.text)
        }

        if let declaration = node.as(ClassDeclSyntax.self),
           isPublic(declaration.modifiers),
           inheritsClientEnvironmentKey(declaration.inheritanceClause)
        {
            typeNames.insert(declaration.name.text)
        }
    }

    private static func isPublic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.public) }
    }

    private static func inheritsClientEnvironmentKey(
        _ inheritanceClause: InheritanceClauseSyntax?
    ) -> Bool {
        guard let inheritanceClause else {
            return false
        }
        return inheritanceClause.inheritedTypes.contains { inherited in
            let name = inherited.type.trimmedDescription
            return name == "ClientEnvironmentKey" || name == "SwiftHTML.ClientEnvironmentKey"
        }
    }
}
