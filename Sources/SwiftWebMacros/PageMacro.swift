import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct PageMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let model = PageModel(attribute: node, declaration: declaration, context: context)

        return [
            DeclSyntax(stringLiteral: """
            var params: \(model.paramsTypeReference) {
                SwiftWeb.RequestContext.current!.params(as: \(model.paramsTypeReference).self)
            }
            """),
            DeclSyntax(stringLiteral: """
            var searchParams: \(model.searchParamsTypeReference) {
                SwiftWeb.RequestContext.current!.searchParams(as: \(model.searchParamsTypeReference).self)
            }
            """),
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let model = PageModel(attribute: node, declaration: declaration, context: context)
        let routeArguments = model.routeArguments
        let getCall = routeArguments.isEmpty
            ? "routes.get"
            : "routes.get(\(routeArguments))"
        let responseExpression = if let loadInvocation = model.loadInvocation {
            """
                        let data = \(loadInvocation)
                        let metadata = \(model.metadataExpression(dataName: "data"))
                        let cache = try await (page as any SwiftWeb.Page).cache
                        return try await page.body(data).encodePageResponse(for: req, metadata: metadata, cache: cache)
            """
        } else {
            """
                        let metadata = try await page.metadata()
                        let cache = try await (page as any SwiftWeb.Page).cache
                        return try await page.body().encodePageResponse(for: req, metadata: metadata, cache: cache)
            """
        }
        let basePathLiteral = model.path.map { #""\#($0)""# } ?? #""/""#
        let pageServiceRegistrations = model.pageStoredProperties
            .map { "                try await SwiftWeb.PageOwnedServices.register(routePage.\($0) as Any, on: application, routes: routes, basePath: basePath)" }
            .joined(separator: "\n")
        let pageServiceRegistrationBody =
            pageServiceRegistrations.isEmpty
            ? """
                  let routePage = self
                  let basePath = SwiftWeb.RoutePath(\(basePathLiteral))
                  try await SwiftWeb.PageOwnedServices.register(routePage, on: application, routes: routes, basePath: basePath)
          """
            : """
                  let routePage = self
                  let basePath = SwiftWeb.RoutePath(\(basePathLiteral))
                  try await SwiftWeb.PageOwnedServices.register(routePage, on: application, routes: routes, basePath: basePath)
          \(pageServiceRegistrations)
          """
        let legacyPageServiceRegistrations = model.pageStoredProperties
            .map { "                try await SwiftWeb.PageOwnedServices.register(routePage.\($0) as Any, on: application)" }
            .joined(separator: "\n")
        let legacyPageServiceRegistrationBody =
            legacyPageServiceRegistrations.isEmpty
            ? """
                  let routePage = self
                  try await SwiftWeb.PageOwnedServices.register(routePage, on: application)
          """
            : """
                  let routePage = self
                  try await SwiftWeb.PageOwnedServices.register(routePage, on: application)
          \(legacyPageServiceRegistrations)
          """

        let extensionDecl = DeclSyntax(stringLiteral: """
        extension \(type.trimmed): SwiftWeb.PageRoute, SwiftWeb.Page {
            static func register(on routes: any SwiftWeb.RoutesBuilder) {
                Self().register(on: routes)
            }

            func register(on routes: any SwiftWeb.RoutesBuilder) {
                let routePage = self
                \(getCall) { req async throws -> SwiftWeb.Response in
                    let params = try SwiftWeb.RouteParametersDecoder(req).decode(\(model.paramsTypeReference).self)
                    let searchParams = try req.query.decode(\(model.searchParamsTypeReference).self)
                    return try await SwiftWeb.RequestContext.withValue(
                        SwiftWeb.RequestValues(request: req, params: params, searchParams: searchParams)
                    ) {
                        let page = routePage
        \(responseExpression)
                    }
                }
            }

            func registerPageOwnedServices(on application: SwiftWeb.Application) async throws {
        \(legacyPageServiceRegistrationBody)
            }

            func registerPageOwnedServices(on application: SwiftWeb.Application, routes: any SwiftWeb.RoutesBuilder) async throws {
        \(pageServiceRegistrationBody)
            }
        }
        """)

        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [extensionDecl]
    }
}

private struct PageModel {
    let path: String?
    let pathParameters: [String]
    let paramsTypeReference: String
    let searchParamsTypeReference: String
    let routeArguments: String
    let hasLoadMethod: Bool
    let loadInvocation: String?
    let loadReturnType: String?
    let metadataMethods: [String: FunctionEffects]
    let pageStoredProperties: [String]

    init(
        attribute: AttributeSyntax,
        declaration: some DeclGroupSyntax,
        context: some MacroExpansionContext
    ) {
        self.path = PageModel.pathLiteral(from: attribute)

        let parsedPath = path.map(PageModel.parsePath(_:)) ?? (components: [], parameters: [])
        self.pathParameters = parsedPath.parameters
        self.routeArguments = parsedPath.components
            .map { #""\#($0)""# }
            .joined(separator: ", ")
        let loadEffects = PageModel.functionEffects(named: "load", in: declaration)
        self.hasLoadMethod = loadEffects != nil
        self.loadReturnType = loadEffects?.returnType
        self.loadInvocation = loadEffects.map { effects in
            let tryPrefix = effects.isThrowing ? "try " : ""
            let awaitPrefix = effects.isAsync ? "await " : ""
            return "\(tryPrefix)\(awaitPrefix)page.load()"
        }
        self.metadataMethods = PageModel.dataMetadataMethods(in: declaration)
        self.pageStoredProperties = PageModel.rootStoredPropertyNames(in: declaration)

        let nestedTypes = PageModel.nestedTypes(in: declaration)
        let paramsFields = nestedTypes["Params"] ?? []
        let hasParams = nestedTypes.keys.contains("Params")
        let hasSearchParams = nestedTypes.keys.contains("SearchParams")

        self.paramsTypeReference = hasParams ? "Params" : "SwiftWeb.NoParams"
        self.searchParamsTypeReference = hasSearchParams ? "SearchParams" : "SwiftWeb.NoSearchParams"

        if path == nil {
            context.diagnose(node: Syntax(attribute), message: "@Page path must be a string literal")
        }

        if !pathParameters.isEmpty && !hasParams {
            context.diagnose(node: Syntax(declaration), message: "@Page path declares parameters, but nested Params is missing")
        }

        if hasParams {
            let fieldNames = Set(paramsFields.map(\.name))
            for parameter in pathParameters where !fieldNames.contains(parameter) {
                context.diagnose(node: Syntax(declaration), message: "@Page path parameter ':\(parameter)' is missing from nested Params")
            }
            for field in paramsFields where !pathParameters.contains(field.name) {
                context.diagnose(node: Syntax(declaration), message: "Params field '\(field.name)' is not declared in the @Page path")
            }
        }
    }

    private static func pathLiteral(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let expression = arguments.first?.expression.as(StringLiteralExprSyntax.self),
              expression.segments.count == 1,
              let segment = expression.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    private static func parsePath(_ path: String) -> (components: [String], parameters: [String]) {
        let components = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        let parameters = components.compactMap { component -> String? in
            guard component.hasPrefix(":") else {
                return nil
            }
            let name = String(component.dropFirst())
            return name.isEmpty ? nil : name
        }
        return (components, parameters)
    }

    func metadataExpression(dataName: String) -> String {
        guard loadReturnType != nil, !metadataMethods.isEmpty else {
            return "try await page.metadata()"
        }

        let titleExpression = metadataCall(
            name: "title",
            dataName: dataName,
            fallback: "try await (page as any SwiftWeb.Page).title"
        )
        let descriptionExpression = metadataCall(
            name: "description",
            dataName: dataName,
            fallback: "try await (page as any SwiftWeb.Page).description"
        )
        let languageExpression = metadataCall(
            name: "language",
            dataName: dataName,
            fallback: "try await (page as any SwiftWeb.Page).language"
        )
        let bodyClassExpression = metadataCall(
            name: "bodyClass",
            dataName: dataName,
            fallback: "try await (page as any SwiftWeb.Page).bodyClass"
        )

        return """
        SwiftWeb.PageMetadata(
                            title: \(titleExpression),
                            description: \(descriptionExpression),
                            language: \(languageExpression),
                            bodyClass: \(bodyClassExpression)
                        )
        """
    }

    private func metadataCall(name: String, dataName: String, fallback: String) -> String {
        guard let effects = metadataMethods[name] else {
            return fallback
        }
        let tryPrefix = effects.isThrowing ? "try " : ""
        let awaitPrefix = effects.isAsync ? "await " : ""
        return "\(tryPrefix)\(awaitPrefix)page.\(name)(\(dataName))"
    }

    private static func functionEffects(named functionName: String, in declaration: some DeclGroupSyntax) -> FunctionEffects? {
        for member in declaration.memberBlock.members {
            guard let functionDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }
            guard functionDecl.name.text == functionName else {
                continue
            }
            let effectSpecifiers = functionDecl.signature.effectSpecifiers
            return FunctionEffects(
                isAsync: effectSpecifiers?.asyncSpecifier != nil,
                isThrowing: effectSpecifiers?.throwsClause != nil,
                returnType: functionDecl.signature.returnClause?.type.trimmedDescription
            )
        }
        return nil
    }

    private static func dataMetadataMethods(in declaration: some DeclGroupSyntax) -> [String: FunctionEffects] {
        var result: [String: FunctionEffects] = [:]

        for member in declaration.memberBlock.members {
            guard let functionDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }
            let name = functionDecl.name.text
            guard name == "title" || name == "description" || name == "language" || name == "bodyClass" else {
                continue
            }
            guard functionDecl.signature.parameterClause.parameters.count == 1 else {
                continue
            }
            let effectSpecifiers = functionDecl.signature.effectSpecifiers
            result[name] = FunctionEffects(
                isAsync: effectSpecifiers?.asyncSpecifier != nil,
                isThrowing: effectSpecifiers?.throwsClause != nil,
                returnType: functionDecl.signature.returnClause?.type.trimmedDescription
            )
        }

        return result
    }

    private static func rootStoredPropertyNames(in declaration: some DeclGroupSyntax) -> [String] {
        var properties: [String] = []

        for member in declaration.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            guard varDecl.attributes.isEmpty else {
                continue
            }
            guard !varDecl.modifiers.contains(where: { $0.name.text == "static" }) else {
                continue
            }

            for binding in varDecl.bindings {
                guard binding.accessorBlock == nil,
                      let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }
                properties.append(pattern.identifier.text)
            }
        }

        return properties
    }

    private static func nestedTypes(in declaration: some DeclGroupSyntax) -> [String: [StoredProperty]] {
        var result: [String: [StoredProperty]] = [:]

        for member in declaration.memberBlock.members {
            guard let structDecl = member.decl.as(StructDeclSyntax.self) else {
                continue
            }
            let name = structDecl.name.text
            guard name == "Params" || name == "SearchParams" else {
                continue
            }

            result[name] = storedProperties(in: structDecl)
        }

        return result
    }

    private static func storedProperties(in structDecl: StructDeclSyntax) -> [StoredProperty] {
        var properties: [StoredProperty] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            for binding in varDecl.bindings {
                guard binding.accessorBlock == nil,
                      let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let type = binding.typeAnnotation?.type else {
                    continue
                }
                properties.append(StoredProperty(
                    name: pattern.identifier.text,
                    type: type.trimmedDescription
                ))
            }
        }

        return properties
    }
}

private struct StoredProperty {
    let name: String
    let type: String
}

private struct FunctionEffects {
    let isAsync: Bool
    let isThrowing: Bool
    let returnType: String?
}

private struct PageDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "SwiftWeb.PageMacro", id: message)
        self.severity = .error
    }
}

private extension MacroExpansionContext {
    func diagnose(node: Syntax, message: String) {
        diagnose(Diagnostic(node: node, message: PageDiagnosticMessage(message: message)))
    }
}
