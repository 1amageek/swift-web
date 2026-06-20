import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ServerActionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            context.diagnose(node: Syntax(declaration), message: "@ServerAction can only be attached to a function")
            return []
        }

        guard ServerActionModel.actorTypeName(in: context) != nil else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must be declared inside a distributed actor")
            return []
        }

        guard !function.modifiers.contains(where: { $0.name.text == "distributed" }) else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must not be distributed")
            return []
        }

        let model = ServerActionModel(function: function, attribute: node, context: context)
        guard model.isValid else {
            return []
        }

        let descriptorName = "_swiftweb_\(model.functionName)ServerActionDescriptor"
        let bridgeName = "_swiftweb_\(model.functionName)ServerActionBridge"
        let actionName = "\(model.functionName)Action"

        return [
            DeclSyntax(stringLiteral: """
            distributed func \(bridgeName)(_ input: \(model.inputType), context: SwiftWeb.ActionInvocationContext) async throws -> \(model.outputType) {
                try await \(model.functionName)(\(model.inputInvocationArgument), context: context)
            }

            let \(descriptorName): SwiftWeb.ServerActionDescriptor = SwiftWeb.ServerActionDescriptor(
                actorType: \(model.actorTypeName).self,
                actorName: String(reflecting: \(model.actorTypeName).self),
                methodName: "\(model.functionName)",
                targetIdentifier: "\(model.targetIdentifier)",
                inputType: \(model.inputType).self,
                outputType: \(model.outputType).self,
                capabilityToken: "\(model.capabilityToken)"
            ) { actor, input, context in
                try await actor.\(bridgeName)(input, context: context)
            }

            nonisolated var \(actionName): SwiftWeb.ActionReference<\(model.inputType), \(model.outputType)> {
                SwiftWeb.ActionReference(
                    actorID: String(describing: id),
                    actorName: String(reflecting: \(model.actorTypeName).self),
                    methodName: "\(model.functionName)",
                    targetIdentifier: "\(model.targetIdentifier)",
                    inputType: String(reflecting: \(model.inputType).self),
                    outputType: String(reflecting: \(model.outputType).self),
                    capabilityToken: "\(model.capabilityToken)"
                )
            }
            """),
        ]
    }
}

private struct ServerActionDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "SwiftWeb.ServerActionMacro", id: message)
        self.severity = .error
    }
}

private extension MacroExpansionContext {
    func diagnose(node: Syntax, message: String) {
        diagnose(Diagnostic(node: node, message: ServerActionDiagnosticMessage(message: message)))
    }
}

struct ServerActionModel {
    let functionName: String
    let actorTypeName: String
    let targetIdentifier: String
    let inputType: String
    let outputType: String
    let capabilityToken: String
    let inputInvocationArgument: String
    let isValid: Bool

    init(function: FunctionDeclSyntax, attribute: AttributeSyntax, context: some MacroExpansionContext) {
        self.functionName = function.name.text
        self.actorTypeName = ServerActionModel.actorTypeName(in: context) ?? "Self"
        self.targetIdentifier = ServerActionModel.targetIdentifier(from: function)
        self.capabilityToken = ServerActionModel.capabilityToken(from: attribute) ?? ""

        let parameters = function.signature.parameterClause.parameters
        let inputParameter = parameters.first
        let contextParameter = parameters.dropFirst().first

        self.inputType = inputParameter?.type.trimmedDescription ?? "SwiftWeb.NoActionInput"
        self.outputType = function.signature.returnClause?.type.trimmedDescription ?? "Swift.Void"
        self.inputInvocationArgument = ServerActionModel.inputInvocationArgument(from: inputParameter)

        var valid = true

        if parameters.isEmpty {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must accept an input value")
            valid = false
        }

        if let contextParameter {
            let externalName = contextParameter.firstName.text
            let typeName = contextParameter.type.trimmedDescription
            if externalName != "context" || typeName != "ActionInvocationContext" && typeName != "SwiftWeb.ActionInvocationContext" {
                context.diagnose(
                    node: Syntax(contextParameter),
                    message: "@ServerAction second parameter must be 'context: ActionInvocationContext'"
                )
                valid = false
            }
        } else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must accept 'context: ActionInvocationContext'")
            valid = false
        }

        if outputType == "Swift.Void" || outputType == "Void" || outputType == "()" {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must return a typed action result")
            valid = false
        }

        self.isValid = valid
    }

    fileprivate static func actorTypeName(in context: some MacroExpansionContext) -> String? {
        for syntax in context.lexicalContext.reversed() {
            if let actor = syntax.as(ActorDeclSyntax.self),
               actor.modifiers.contains(where: { $0.name.text == "distributed" }) {
                return actor.name.text
            }
        }
        return nil
    }

    private static func targetIdentifier(from function: FunctionDeclSyntax) -> String {
        let parameterLabels = function.signature.parameterClause.parameters.map { parameter in
            let externalName = parameter.firstName.text
            return externalName == "_" ? "_" : externalName
        }
        guard !parameterLabels.isEmpty else {
            return function.name.text
        }
        return "\(function.name.text)(\(parameterLabels.joined(separator: ":")):)"
    }

    private static func inputInvocationArgument(from parameter: FunctionParameterSyntax?) -> String {
        guard let parameter else {
            return "input"
        }

        let externalName = parameter.firstName.text
        if externalName == "_" {
            return "input"
        }
        return "\(externalName): input"
    }

    private static func capabilityToken(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        for argument in arguments where argument.label?.text == "capabilityToken" {
            guard let expression = argument.expression.as(StringLiteralExprSyntax.self),
                  expression.segments.count == 1,
                  let segment = expression.segments.first?.as(StringSegmentSyntax.self) else {
                return nil
            }
            return segment.content.text
        }

        return nil
    }
}
