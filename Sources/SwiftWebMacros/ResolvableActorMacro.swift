#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ResolvableActorMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ActorDeclSyntax.self) else {
            context.diagnose(node: Syntax(declaration), message: "@ResolvableActor can only be attached to an actor")
            return []
        }
        guard let contract = contractType(from: node) else {
            context.diagnose(node: Syntax(node), message: "@ResolvableActor requires a protocol metatype")
            return []
        }

        let stub = stubType(for: contract)
        let extensionDecl = DeclSyntax(stringLiteral: """
        extension \(type.trimmed): SwiftWebActorExporting {
            typealias SwiftWebActorContract = \(stub)

            nonisolated static var swiftWebActorContractKey: SwiftWebActorContractKey {
                SwiftWebActorContractKey(String(reflecting: (any \(contract)).self))
            }

            nonisolated static func _swiftWebActorContractTypeCheck(_ actor: \(type.trimmed)) -> any \(contract) {
                actor
            }
        }
        """)
        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [extensionDecl]
    }

    private static func contractType(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let expression = arguments.first?.expression
        else {
            return nil
        }

        var source = expression.trimmedDescription
        if source.hasSuffix(".self") {
            source.removeLast(".self".count)
        }
        source = normalizedExistentialType(source)
        guard !source.isEmpty else {
            return nil
        }
        return source
    }

    private static func normalizedExistentialType(_ source: String) -> String {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("("), value.hasSuffix(")") {
            value.removeFirst()
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.hasPrefix("any ") {
            value.removeFirst("any ".count)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stubType(for contract: String) -> String {
        let components = contract.split(separator: ".").map(String.init)
        guard let last = components.last else {
            return "$\(contract)"
        }
        let prefix = components.dropLast().joined(separator: ".")
        if prefix.isEmpty {
            return "$\(last)"
        }
        return "\(prefix).$\(last)"
    }
}

private struct ResolvableActorDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "SwiftWeb.ResolvableActorMacro", id: message)
        self.severity = .error
    }
}

private extension MacroExpansionContext {
    func diagnose(node: Syntax, message: String) {
        diagnose(Diagnostic(node: node, message: ResolvableActorDiagnosticMessage(message: message)))
    }
}
