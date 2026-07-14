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

        var members: [DeclSyntax] = [
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

        if let binder = model.paramsBinder() {
            members.append(DeclSyntax(stringLiteral: binder))
        }
        if let binder = model.searchParamsBinder() {
            members.append(DeclSyntax(stringLiteral: binder))
        }
        if let urlBuilder = model.urlBuilder() {
            members.append(DeclSyntax(stringLiteral: urlBuilder))
        }

        return members
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
            .map { "                try await SwiftWeb.PageOwnedServices.registerService(routePage.\($0), on: application, routes: routes, basePath: basePath)" }
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
            .map { "                try await SwiftWeb.PageOwnedServices.registerService(routePage.\($0), on: application)" }
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
                let swiftWebActorBindings = SwiftWeb.SwiftWebActorRenderContext.currentScope
                \(getCall) { req async throws -> SwiftWeb.Response in
                    try await SwiftWeb.SwiftWebActorRenderContext.withValue(swiftWebActorBindings) {
        \(model.bindingStatements())
                        return try await SwiftWeb.RequestContext.withValue(
                            SwiftWeb.RequestValues(request: req, params: params, searchParams: searchParams)
                        ) {
                            let page = routePage
        \(responseExpression)
                        }
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
    let pathComponents: [String]
    let pathParameters: [String]
    let paramsTypeReference: String
    let searchParamsTypeReference: String
    let routeArguments: String
    let hasParams: Bool
    let hasSearchParams: Bool
    let paramsFields: [StoredProperty]
    let searchParamsFields: [StoredProperty]
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
        self.pathComponents = parsedPath.components
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
        self.paramsFields = nestedTypes["Params"] ?? []
        self.searchParamsFields = nestedTypes["SearchParams"] ?? []
        self.hasParams = nestedTypes.keys.contains("Params")
        self.hasSearchParams = nestedTypes.keys.contains("SearchParams")

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
            for field in paramsFields where field.isOptional || field.isArray || field.defaultExpression != nil {
                context.diagnose(node: Syntax(declaration), message: "Params field '\(field.name)' must be a plain required value: path parameters are always present when the route matches")
            }
        }

        for field in searchParamsFields {
            if field.isLet, field.defaultExpression != nil {
                context.diagnose(node: Syntax(declaration), message: "SearchParams field '\(field.name)' must be 'var' to declare a default value ('let' with an initializer is excluded from the memberwise initializer)")
            }
            if field.isOptional, let defaultExpression = field.defaultExpression, defaultExpression != "nil" {
                context.diagnose(node: Syntax(declaration), message: "SearchParams field '\(field.name)' is Optional and cannot also declare a non-nil default; drop the initializer or make the type non-optional")
            }
        }
    }

    // MARK: Generated binding

    func paramsBinder() -> String? {
        guard hasParams else {
            return nil
        }
        let arguments = paramsFields
            .map { "        \($0.name): try parameters.require(\"\($0.name)\")" }
            .joined(separator: ",\n")
        return """
        static func _bindParams(_ parameters: SwiftWeb.PathParameters) throws(SwiftWeb.ParameterError) -> Params {
            Params(
        \(arguments)
            )
        }
        """
    }

    func searchParamsBinder() -> String? {
        guard hasSearchParams else {
            return nil
        }
        let arguments = searchParamsFields.map { field -> String in
            let accessor: String
            if field.isArray, let defaultExpression = field.defaultExpression {
                accessor = "try query.values(\"\(field.name)\", default: \(defaultExpression))"
            } else if field.isArray {
                accessor = "try query.values(\"\(field.name)\")"
            } else if field.isOptional {
                accessor = "try query.value(\"\(field.name)\")"
            } else if let defaultExpression = field.defaultExpression {
                accessor = "try query.value(\"\(field.name)\", default: \(defaultExpression))"
            } else {
                accessor = "try query.require(\"\(field.name)\")"
            }
            return "        \(field.name): \(accessor)"
        }
        .joined(separator: ",\n")
        return """
        static func _bindSearchParams(_ query: SwiftWeb.QueryParameters) throws(SwiftWeb.ParameterError) -> SearchParams {
            SearchParams(
        \(arguments)
            )
        }
        """
    }

    /// The binding statements inside the generated route handler. Binding
    /// failures short-circuit to `400 Bad Request` before the page runs.
    func bindingStatements() -> String {
        guard hasParams || hasSearchParams else {
            return """
                        let params = SwiftWeb.NoParams()
                        let searchParams = SwiftWeb.NoSearchParams()
            """
        }
        let paramsExpression = hasParams
            ? "try Self._bindParams(req.parameters)"
            : "SwiftWeb.NoParams()"
        let searchParamsExpression = hasSearchParams
            ? "try Self._bindSearchParams(req.queryParameters)"
            : "SwiftWeb.NoSearchParams()"
        return """
                        let params: \(paramsTypeReference)
                        let searchParams: \(searchParamsTypeReference)
                        do throws(SwiftWeb.ParameterError) {
                            params = \(paramsExpression)
                            searchParams = \(searchParamsExpression)
                        } catch {
                            return error.badRequestResponse()
                        }
            """
    }

    // MARK: Generated URL builder

    func urlBuilder() -> String? {
        guard path != nil else {
            return nil
        }
        let paramsByName = Dictionary(uniqueKeysWithValues: paramsFields.map { ($0.name, $0) })

        var arguments: [String] = []
        for parameter in pathParameters {
            guard let field = paramsByName[parameter] else {
                return nil // inconsistent declaration; already diagnosed
            }
            arguments.append("\(parameter): \(field.type)")
        }
        if hasSearchParams {
            let allFieldsHaveDefaults = searchParamsFields.allSatisfy { field in
                (field.isOptional && !field.isLet) || field.defaultExpression != nil
            }
            arguments.append(allFieldsHaveDefaults ? "searchParams: SearchParams = SearchParams()" : "searchParams: SearchParams")
        }

        var statements: [String] = ["    var builder = SwiftWeb.RouteURLBuilder()"]
        for component in pathComponents {
            if component.hasPrefix(":") {
                statements.append("    builder.appendPathSegment(\(component.dropFirst()))")
            } else {
                statements.append("    builder.appendPathSegment(\"\(component)\")")
            }
        }
        for field in searchParamsFields {
            if field.isArray {
                statements.append("""
                    for element in searchParams.\(field.name) {
                        builder.appendQuery("\(field.name)", SwiftWeb.RouteURLBuilder.wire(element))
                    }
                """)
            } else if field.isOptional {
                statements.append("""
                    if let value = searchParams.\(field.name) {
                        builder.appendQuery("\(field.name)", SwiftWeb.RouteURLBuilder.wire(value))
                    }
                """)
            } else if let defaultExpression = field.defaultExpression {
                statements.append("""
                    let default_\(field.name): \(field.type) = \(defaultExpression)
                    if SwiftWeb.RouteURLBuilder.wire(searchParams.\(field.name)) != SwiftWeb.RouteURLBuilder.wire(default_\(field.name)) {
                        builder.appendQuery("\(field.name)", SwiftWeb.RouteURLBuilder.wire(searchParams.\(field.name)))
                    }
                """)
            } else {
                statements.append("""
                    builder.appendQuery("\(field.name)", SwiftWeb.RouteURLBuilder.wire(searchParams.\(field.name)))
                """)
            }
        }
        statements.append("    return builder.url")

        return """
        static func url(\(arguments.joined(separator: ", "))) -> SwiftWeb.RouteURL {
        \(statements.joined(separator: "\n"))
        }
        """
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
            guard !varDecl.modifiers.contains(where: { $0.name.text == "static" }) else {
                continue
            }
            let isLet = varDecl.bindingSpecifier.text == "let"

            for binding in varDecl.bindings {
                guard binding.accessorBlock == nil,
                      let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let type = binding.typeAnnotation?.type else {
                    continue
                }
                let isOptional = type.is(OptionalTypeSyntax.self)
                    || (type.as(IdentifierTypeSyntax.self)?.name.text == "Optional")
                let isArray = type.is(ArrayTypeSyntax.self)
                properties.append(StoredProperty(
                    name: pattern.identifier.text,
                    type: type.trimmedDescription,
                    isOptional: isOptional,
                    isArray: isArray,
                    isLet: isLet,
                    defaultExpression: binding.initializer?.value.trimmedDescription
                ))
            }
        }

        return properties
    }
}

private struct StoredProperty {
    let name: String
    let type: String
    let isOptional: Bool
    let isArray: Bool
    let isLet: Bool
    let defaultExpression: String?
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
