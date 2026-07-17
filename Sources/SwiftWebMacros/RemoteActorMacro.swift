import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RemoteActorMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            context.diagnose(node: Syntax(declaration), message: "@RemoteActor can only be attached to a property")
            return []
        }
        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            context.diagnose(node: Syntax(variable.bindingSpecifier), message: "@RemoteActor requires a 'var' property")
            return []
        }
        guard !variable.modifiers.contains(where: Self.isTypeScopedModifier) else {
            context.diagnose(node: Syntax(variable), message: "@RemoteActor cannot be applied to a static property")
            return []
        }
        guard variable.bindings.count == 1, let binding = variable.bindings.first else {
            context.diagnose(node: Syntax(variable), message: "@RemoteActor requires a single property binding")
            return []
        }
        guard binding.initializer == nil else {
            context.diagnose(node: Syntax(binding), message: "@RemoteActor property cannot have an initial value")
            return []
        }
        guard binding.accessorBlock == nil else {
            context.diagnose(node: Syntax(binding), message: "@RemoteActor property cannot declare accessors")
            return []
        }
        guard let type = binding.typeAnnotation?.type.trimmed else {
            context.diagnose(node: Syntax(binding), message: "@RemoteActor requires an explicit type annotation")
            return []
        }

        let serviceType = type.description
        return [
            """
            get {
                SwiftWebActorBinding.resolve(
                    (\(raw: serviceType)).self,
                    contract: SwiftWebActorContractKey(String(reflecting: (\(raw: serviceType)).self))
                )
            }
            """
        ]
    }

    private static func isTypeScopedModifier(_ modifier: DeclModifierSyntax) -> Bool {
        modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
    }
}

private struct RemoteActorMacroDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "SwiftWeb.RemoteActorMacro", id: message)
        self.severity = .error
    }
}

private extension MacroExpansionContext {
    func diagnose(node: Syntax, message: String) {
        diagnose(Diagnostic(node: node, message: RemoteActorMacroDiagnosticMessage(message: message)))
    }
}
