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

        guard ServerActionModel.handlerDeclaration(containing: function, in: context) != nil else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must be declared inside an actor, class, or struct")
            return []
        }

        guard !function.modifiers.contains(where: { $0.name.text == "distributed" }) else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must not be distributed; use @Resolvable for distributed actor RPC")
            return []
        }

        guard !function.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) else {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must be an instance function")
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
            func \(bridgeName)(_ input: \(model.inputType), context: SwiftWeb.ActionInvocationContext) async throws -> \(model.outputType) {
                \(model.actionInvocationExpression)
            }
            """),
            DeclSyntax(stringLiteral: """
            let \(descriptorName): SwiftWeb.ServerActionDescriptor = SwiftWeb.ServerActionDescriptor(
                handlerType: \(model.handlerTypeName).self,
                method: \(model.methodExpression),
                path: \(model.pathLiteral),
                inputType: \(model.inputType).self,
                outputType: \(model.outputType).self
            ) { handler, input, context in
                try await handler.\(bridgeName)(input, context: context)
            }
            """),
            DeclSyntax(stringLiteral: """
            \(model.actionReferenceIsolation)var \(actionName): SwiftWeb.ActionReference<\(model.inputType), \(model.outputType)> {
                SwiftWeb.ActionReference(
                    path: SwiftWeb.ServerActionPath.renderedPath(\(model.pathLiteral)),
                    httpMethod: \(model.methodExpression),
                    inputType: String(reflecting: \(model.inputType).self),
                    outputType: String(reflecting: \(model.outputType).self)
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
    let handlerTypeName: String
    let actionReferenceIsolation: String
    let methodExpression: String
    let pathLiteral: String
    let inputType: String
    let outputType: String
    let actionInvocationExpression: String
    let isValid: Bool

    init(function: FunctionDeclSyntax, attribute: AttributeSyntax, context: some MacroExpansionContext) {
        self.functionName = function.name.text
        let handlerDeclaration = ServerActionModel.handlerDeclaration(containing: function, in: context)
        self.handlerTypeName = handlerDeclaration?.typeName ?? "Self"
        self.actionReferenceIsolation = handlerDeclaration?.actionReferenceIsolation ?? ""
        let route = ServerActionModel.routeLiteral(from: attribute, context: context)
        self.methodExpression = route.methodExpression
        self.pathLiteral = route.pathLiteral ?? #""""#

        let parameters = function.signature.parameterClause.parameters
        let inputParameter = parameters.first
        let contextParameter = parameters.dropFirst().first
        let effects = function.signature.effectSpecifiers
        let tryPrefix = effects?.throwsClause == nil ? "" : "try "
        let awaitPrefix = effects?.asyncSpecifier == nil ? "" : "await "

        self.inputType = inputParameter?.type.trimmedDescription ?? "SwiftWeb.NoActionInput"
        self.outputType = function.signature.returnClause?.type.trimmedDescription ?? "Swift.Void"
        let contextInvocation = contextParameter == nil ? "" : ", context: context"
        self.actionInvocationExpression = "\(tryPrefix)\(awaitPrefix)\(function.name.text)(\(ServerActionModel.inputInvocationArgument(from: inputParameter))\(contextInvocation))"

        var valid = route.isValid

        if parameters.isEmpty {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must accept an input value")
            valid = false
        }

        if parameters.count > 2 {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must accept only input and optional context parameters")
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
        }

        if outputType == "Swift.Void" || outputType == "Void" || outputType == "()" {
            context.diagnose(node: Syntax(function), message: "@ServerAction function must return a typed action result")
            valid = false
        }

        self.isValid = valid
    }

    fileprivate static func handlerDeclaration(
        containing function: FunctionDeclSyntax,
        in context: some MacroExpansionContext
    ) -> ServerActionHandlerDeclaration? {
        var parent = Syntax(function).parent
        while let syntax = parent {
            if let actor = syntax.as(ActorDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: actor.name.text,
                    actionReferenceIsolation: "nonisolated "
                )
            }
            if let classDecl = syntax.as(ClassDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: classDecl.name.text,
                    actionReferenceIsolation: ""
                )
            }
            if let structDecl = syntax.as(StructDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: structDecl.name.text,
                    actionReferenceIsolation: ""
                )
            }
            parent = syntax.parent
        }

        for syntax in context.lexicalContext.reversed() {
            if let actor = syntax.as(ActorDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: actor.name.text,
                    actionReferenceIsolation: "nonisolated "
                )
            }
            if let classDecl = syntax.as(ClassDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: classDecl.name.text,
                    actionReferenceIsolation: ""
                )
            }
            if let structDecl = syntax.as(StructDeclSyntax.self) {
                return ServerActionHandlerDeclaration(
                    typeName: structDecl.name.text,
                    actionReferenceIsolation: ""
                )
            }
        }
        return nil
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

    private static func routeLiteral(
        from attribute: AttributeSyntax,
        context: some MacroExpansionContext
    ) -> ServerActionRouteLiteral {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self), !arguments.isEmpty else {
            context.diagnose(node: Syntax(attribute), message: "@ServerAction must declare an HTTP path")
            return ServerActionRouteLiteral(methodExpression: "SwiftWeb.ServerActionMethod.post", pathLiteral: nil, isValid: false)
        }

        if arguments.count == 1 {
            let argument = arguments[arguments.startIndex]
            guard argument.label == nil else {
                context.diagnose(node: Syntax(argument), message: "@ServerAction path must be an unlabeled string literal")
                return ServerActionRouteLiteral(methodExpression: "SwiftWeb.ServerActionMethod.post", pathLiteral: nil, isValid: false)
            }
            let pathLiteral = stringLiteral(from: argument.expression, context: context)
            return ServerActionRouteLiteral(
                methodExpression: "SwiftWeb.ServerActionMethod.post",
                pathLiteral: pathLiteral,
                isValid: pathLiteral != nil
            )
        }

        let methodArgument = arguments[arguments.startIndex]
        let pathArgument = arguments[arguments.index(after: arguments.startIndex)]
        var valid = true

        guard methodArgument.label == nil, pathArgument.label == nil else {
            context.diagnose(node: Syntax(attribute), message: "@ServerAction method and path must be unlabeled")
            valid = false
            return ServerActionRouteLiteral(methodExpression: "SwiftWeb.ServerActionMethod.post", pathLiteral: nil, isValid: false)
        }

        let methodExpression = methodLiteral(from: methodArgument.expression, context: context)
        if methodExpression == nil {
            valid = false
        }
        let pathLiteral = stringLiteral(from: pathArgument.expression, context: context)
        if pathLiteral == nil {
            valid = false
        }

        return ServerActionRouteLiteral(
            methodExpression: methodExpression ?? "SwiftWeb.ServerActionMethod.post",
            pathLiteral: pathLiteral,
            isValid: valid
        )
    }

    private static func stringLiteral(
        from expression: ExprSyntax,
        context: some MacroExpansionContext
    ) -> String? {
        guard let expression = expression.as(StringLiteralExprSyntax.self),
              expression.segments.count == 1,
              expression.segments.first?.as(StringSegmentSyntax.self) != nil else {
            context.diagnose(node: Syntax(expression), message: "@ServerAction path must be a static string literal")
            return nil
        }
        return expression.trimmedDescription
    }

    private static func methodLiteral(
        from expression: ExprSyntax,
        context: some MacroExpansionContext
    ) -> String? {
        let source = expression.trimmedDescription
        let methodName = source.split(separator: ".").last.map(String.init) ?? source
        switch methodName {
        case "get", "post", "put", "delete":
            return "SwiftWeb.ServerActionMethod.\(methodName)"
        default:
            context.diagnose(node: Syntax(expression), message: "@ServerAction method must be .get, .post, .put, or .delete")
            return nil
        }
    }
}

private struct ServerActionHandlerDeclaration {
    let typeName: String
    let actionReferenceIsolation: String
}

private struct ServerActionRouteLiteral {
    let methodExpression: String
    let pathLiteral: String?
    var isValid: Bool = true
}
