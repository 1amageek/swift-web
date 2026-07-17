import SwiftParser
import SwiftSyntax

/// Expands `@RemoteActor` properties in copied client component sources into their
/// resolved accessor form so generated browser WASM packages compile without
/// the SwiftWebMacros plugin or swift-syntax.
///
/// The expansion mirrors `SwiftWebMacros.RemoteActorMacro`: the property becomes a
/// computed property whose getter resolves the service from the active
/// `SwiftWebActorBindingContext` scope.
enum SwiftWebClientActorPropertyExpander {
    static func expandActorProperties(inSource source: String, filePath: String) throws -> String {
        // Fast path: the attribute may be spelled `@RemoteActor` or module-qualified
        // (`@SwiftWebActors.Actor`), so gate parsing on the bare name.
        guard source.contains("RemoteActor") else {
            return source
        }
        let file = Parser.parse(source: source)
        let rewriter = ActorPropertyRewriter(filePath: filePath)
        let rewritten = rewriter.visit(file)
        if let failure = rewriter.failure {
            throw failure
        }
        guard rewriter.didRewrite else {
            return source
        }
        return rewritten.description
    }
}

enum SwiftWebClientActorPropertyExpansionError: Error, CustomStringConvertible, Equatable {
    case unsupportedActorProperty(filePath: String, reason: String)

    var description: String {
        switch self {
        case .unsupportedActorProperty(let filePath, let reason):
            "Cannot expand @RemoteActor property in \(filePath): \(reason)"
        }
    }
}

private final class ActorPropertyRewriter: SyntaxRewriter {
    private let filePath: String
    private(set) var didRewrite = false
    private(set) var failure: SwiftWebClientActorPropertyExpansionError?

    init(filePath: String) {
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        guard failure == nil else {
            return DeclSyntax(node)
        }
        guard let actorAttribute = Self.actorAttribute(in: node) else {
            return super.visit(node)
        }
        guard node.bindingSpecifier.tokenKind == .keyword(.var) else {
            return fail(node, reason: "@RemoteActor requires a 'var' property")
        }
        guard !node.modifiers.contains(where: Self.isTypeScopedModifier) else {
            return fail(node, reason: "@RemoteActor cannot be applied to a static property")
        }
        guard node.bindings.count == 1, let binding = node.bindings.first else {
            return fail(node, reason: "@RemoteActor requires a single property binding")
        }
        guard binding.initializer == nil else {
            return fail(node, reason: "@RemoteActor property cannot have an initial value")
        }
        guard binding.accessorBlock == nil else {
            return fail(node, reason: "@RemoteActor property cannot declare accessors")
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return fail(node, reason: "@RemoteActor requires an identifier property name")
        }
        guard let type = binding.typeAnnotation?.type.trimmed else {
            return fail(node, reason: "@RemoteActor requires an explicit type annotation")
        }
        guard actorAttribute.arguments == nil else {
            return fail(node, reason: "@RemoteActor does not take arguments")
        }

        let serviceType = type.description
        let indent = Self.declarationIndent(of: node)
        let otherAttributes = node.attributes
            .filter { attribute in
                if case .attribute(let value) = attribute {
                    return value.id != actorAttribute.id
                }
                return true
            }
            .map { $0.trimmedDescription }
        let modifiers = node.modifiers.map { $0.trimmedDescription }
        let declarationHead = (otherAttributes + modifiers + ["var"]).joined(separator: " ")

        let lines = [
            "\(declarationHead) \(identifier): \(serviceType) {",
            "    get {",
            "        SwiftWebActorBinding.resolve(",
            "            (\(serviceType)).self,",
            "            contract: SwiftWebActorContractKey(String(reflecting: (\(serviceType)).self))",
            "        )",
            "    }",
            "}",
        ]
        let declarationSource = lines.enumerated()
            .map { index, line in
                index == 0 ? line : indent + line
            }
            .joined(separator: "\n")

        let parsedDeclaration = Parser.parse(source: declarationSource)
        guard parsedDeclaration.statements.count == 1,
            let statement = parsedDeclaration.statements.first,
            case .decl(var declaration) = statement.item,
            declaration.is(VariableDeclSyntax.self)
        else {
            return fail(node, reason: "internal error: expanded declaration failed to parse")
        }

        didRewrite = true
        declaration.leadingTrivia = node.leadingTrivia
        declaration.trailingTrivia = node.trailingTrivia
        return declaration
    }

    private func fail(_ node: VariableDeclSyntax, reason: String) -> DeclSyntax {
        failure = .unsupportedActorProperty(filePath: filePath, reason: reason)
        return DeclSyntax(node)
    }

    private static func actorAttribute(in node: VariableDeclSyntax) -> AttributeSyntax? {
        for element in node.attributes {
            guard case .attribute(let attribute) = element else {
                continue
            }
            let name = attribute.attributeName.trimmedDescription
            let canonicalName = name.split(separator: ".").last.map(String.init) ?? name
            if canonicalName == "RemoteActor" {
                return attribute
            }
        }
        return nil
    }

    private static func isTypeScopedModifier(_ modifier: DeclModifierSyntax) -> Bool {
        modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
    }

    private static func declarationIndent(of node: VariableDeclSyntax) -> String {
        let leadingText = node.leadingTrivia.description
        guard let lastNewline = leadingText.lastIndex(of: "\n") else {
            return ""
        }
        let indentText = leadingText[leadingText.index(after: lastNewline)...]
        return indentText.allSatisfy { $0 == " " || $0 == "\t" } ? String(indentText) : ""
    }
}
