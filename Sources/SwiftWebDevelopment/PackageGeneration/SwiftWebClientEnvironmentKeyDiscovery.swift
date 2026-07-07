import Foundation
import SwiftParser
import SwiftSyntax

/// Discovers app-defined `ClientEnvironmentKey` conformances so the generated
/// WASM entrypoint can extend `ClientEnvironmentRegistry.swiftWebUI` with
/// them. Without registration, hydration aborts with `missingDecoder` for any
/// scene- or request-provided value whose key the framework does not know.
///
/// Conformances are collected wherever they are declared — on the type itself,
/// through an `extension`, and at any nesting depth — mirroring
/// `SwiftWebClientComponentDiscovery`. Nested types are reported by their
/// fully qualified name so the generated `.registering(...)` resolves. A
/// type-declaration conformance is only collected when the type and every
/// enclosing type are `public`/`open`, since the generated entrypoint is a
/// separate target; a non-public key surfaces as a build error there rather
/// than as a silent miss that would abort hydration at runtime.
struct SwiftWebClientEnvironmentKeyDiscovery {
    static func discover(
        in swiftFiles: [(url: URL, relativePath: String)]
    ) throws -> [String] {
        var typeNames: Set<String> = []
        for file in swiftFiles {
            let source = try String(contentsOf: file.url, encoding: .utf8)
            let syntax = Parser.parse(source: source)
            let visitor = ClientEnvironmentKeyVisitor(viewMode: .sourceAccurate)
            visitor.walk(syntax)
            typeNames.formUnion(visitor.typeNames)
        }
        return typeNames.sorted()
    }
}

private final class ClientEnvironmentKeyVisitor: SyntaxVisitor {
    private(set) var typeNames: Set<String> = []
    private var scope: [(name: String, isPublic: Bool)] = []

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(node.name.text, node.modifiers, node.inheritanceClause)
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { scope.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(node.name.text, node.modifiers, node.inheritanceClause)
        return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(node.name.text, node.modifiers, node.inheritanceClause)
        return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(node.name.text, node.modifiers, node.inheritanceClause)
        return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { scope.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // An extension adds the conformance to an already-declared type; the
        // extended type name is used as written (already qualified). The key's
        // members must be public to be referenced from the entrypoint, so no
        // extra public gate is applied here.
        let name = node.extendedType.trimmedDescription
        if inheritsClientEnvironmentKey(node.inheritanceClause) {
            typeNames.insert(name)
        }
        scope.append((name, true))
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { scope.removeLast() }

    private func enterType(
        _ name: String,
        _ modifiers: DeclModifierListSyntax,
        _ inheritance: InheritanceClauseSyntax?
    ) {
        let isPublic = isPublicOrOpen(modifiers)
        if inheritsClientEnvironmentKey(inheritance), isPublic, scope.allSatisfy(\.isPublic) {
            typeNames.insert((scope.map(\.name) + [name]).joined(separator: "."))
        }
        scope.append((name, isPublic))
    }

    private func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains {
            $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open)
        }
    }

    private func inheritsClientEnvironmentKey(
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
