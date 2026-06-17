import Foundation
import SwiftHTML
import SwiftParser
import SwiftSyntax

struct SwiftWebClientComponentDiscovery {
    static func discover(
        in swiftFiles: [(url: URL, relativePath: String)]
    ) throws -> [ClientComponentDeclaration] {
        let parsedFiles = try swiftFiles.map { file in
            let source = try String(contentsOf: file.url, encoding: .utf8)
            return ParsedFile(
                url: file.url,
                relativePath: file.relativePath,
                syntax: Parser.parse(source: source)
            )
        }

        var definitions: [String: ClientComponentDeclaration] = [:]
        for parsedFile in parsedFiles {
            for declaration in componentDefinitions(in: parsedFile.syntax) {
                definitions[declaration.typeName] = definitions[declaration.typeName]?.merged(with: declaration)
                    ?? declaration
            }
        }

        var usageVariants: [ClientComponentDeclaration] = []
        for parsedFile in parsedFiles {
            usageVariants.append(contentsOf: componentUsages(in: parsedFile.syntax, definitions: definitions))
        }

        let usageTypeNames = Set(usageVariants.map(\.typeName))
        let fallbackDefinitions = definitions.values.filter { declaration in
            !usageTypeNames.contains(declaration.typeName)
        }
        let declarations = fallbackDefinitions + usageVariants

        return uniqueDeclarations(declarations)
    }

    private static func componentDefinitions(
        in syntax: SourceFileSyntax
    ) -> [ClientComponentDeclaration] {
        var declarations: [ClientComponentDeclaration] = []
        visit(Syntax(syntax)) { node in
            if let declaration = node.as(StructDeclSyntax.self),
               inheritsClientComponent(declaration.inheritanceClause)
            {
                declarations.append(contract(
                    for: declaration.name.text,
                    memberBlock: declaration.memberBlock
                ))
            }

            if let declaration = node.as(ClassDeclSyntax.self),
               inheritsClientComponent(declaration.inheritanceClause)
            {
                declarations.append(contract(
                    for: declaration.name.text,
                    memberBlock: declaration.memberBlock
                ))
            }

            if let declaration = node.as(ActorDeclSyntax.self),
               inheritsClientComponent(declaration.inheritanceClause)
            {
                declarations.append(contract(
                    for: declaration.name.text,
                    memberBlock: declaration.memberBlock
                ))
            }

            if let declaration = node.as(ExtensionDeclSyntax.self),
               inheritsClientComponent(declaration.inheritanceClause),
               let typeName = canonicalTypeName(declaration.extendedType.trimmedDescription)
            {
                declarations.append(contract(
                    for: typeName,
                    memberBlock: declaration.memberBlock
                ))
            }
        }
        return declarations
    }

    private static func componentUsages(
        in syntax: SourceFileSyntax,
        definitions: [String: ClientComponentDeclaration]
    ) -> [ClientComponentDeclaration] {
        var declarations: [ClientComponentDeclaration] = []

        func visitUsage(_ node: Syntax) {
            if let call = node.as(FunctionCallExprSyntax.self),
               let declaration = componentUsage(from: call, definitions: definitions)
            {
                declarations.append(declaration)
                return
            }

            for child in node.children(viewMode: .sourceAccurate) {
                visitUsage(child)
            }
        }

        visitUsage(Syntax(syntax))
        return declarations
    }

    private static func componentUsage(
        from call: FunctionCallExprSyntax,
        definitions: [String: ClientComponentDeclaration]
    ) -> ClientComponentDeclaration? {
        if let typeName = canonicalTypeName(call.calledExpression.trimmedDescription),
           let declaration = definitions[typeName]
        {
            return declaration
        }

        guard let memberAccess = call.calledExpression.as(MemberAccessExprSyntax.self),
              let baseCall = memberAccess.base?.as(FunctionCallExprSyntax.self),
              var declaration = componentUsage(from: baseCall, definitions: definitions)
        else {
            return nil
        }

        let modifierName = memberAccess.declName.baseName.text
        switch modifierName {
        case "loadPolicy":
            if let expression = call.arguments.first?.expression.trimmedDescription,
               let loadPolicy = parseLoadPolicyExpression(expression)
            {
                declaration.loadPolicy = loadPolicy
            }
        case "bundle":
            if let expression = call.arguments.first?.expression.trimmedDescription,
               let bundlePolicy = parseBundlePolicyExpression(expression)
            {
                declaration.bundlePolicy = bundlePolicy
            }
        default:
            break
        }
        return declaration
    }

    private static func contract(
        for typeName: String,
        memberBlock: MemberBlockSyntax
    ) -> ClientComponentDeclaration {
        var declaration = ClientComponentDeclaration(typeName: typeName)

        for member in memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.modifiers.contains(where: { $0.name.text == "static" })
            else {
                continue
            }

            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      let expression = binding.initializer?.value.trimmedDescription
                else {
                    continue
                }

                switch identifier {
                case "loadPolicy":
                    if let loadPolicy = parseLoadPolicyExpression(expression) {
                        declaration.loadPolicy = loadPolicy
                    }
                case "bundle":
                    if let bundlePolicy = parseBundlePolicyExpression(expression) {
                        declaration.bundlePolicy = bundlePolicy
                    }
                default:
                    break
                }
            }
        }

        return declaration
    }

    private static func inheritsClientComponent(_ inheritanceClause: InheritanceClauseSyntax?) -> Bool {
        guard let inheritanceClause else {
            return false
        }

        return inheritanceClause.inheritedTypes.contains { inheritedType in
            canonicalTypeName(inheritedType.type.trimmedDescription) == "ClientComponent"
        }
    }

    private static func parseLoadPolicyExpression(_ expression: String) -> LoadPolicy? {
        for loadPolicy in loadPolicies where expression.contains(".\(loadPolicy.rawValue)") {
            return loadPolicy
        }
        return nil
    }

    private static func parseBundlePolicyExpression(_ expression: String) -> BundlePolicy? {
        if expression.contains(".main") {
            return .main
        }
        if expression.contains(".component") {
            return .component
        }
        if let name = bundleName(for: ".named", in: expression) {
            return .named(name)
        }
        if let name = bundleName(for: ".shared", in: expression) {
            return .shared(name)
        }
        return nil
    }

    private static func bundleName(for prefix: String, in expression: String) -> String? {
        guard let prefixRange = expression.range(of: prefix),
              let openingQuote = expression[prefixRange.upperBound...].firstIndex(of: "\"")
        else {
            return nil
        }
        let nameStart = expression.index(after: openingQuote)
        guard let closingQuote = expression[nameStart...].firstIndex(of: "\"") else {
            return nil
        }
        return String(expression[nameStart..<closingQuote])
    }

    private static func canonicalTypeName(_ source: String) -> String? {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix(".") else {
            return nil
        }

        if let genericStart = value.firstIndex(of: "<") {
            value = String(value[..<genericStart])
        }

        if value.hasSuffix(".init") {
            value.removeLast(".init".count)
        }

        if let lastComponent = value.split(separator: ".").last {
            value = String(lastComponent)
        }

        guard value.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    private static func uniqueDeclarations(
        _ declarations: [ClientComponentDeclaration]
    ) -> [ClientComponentDeclaration] {
        var seen = Set<String>()
        var unique: [ClientComponentDeclaration] = []
        for declaration in declarations.sorted(by: declarationSort) where seen.insert(declaration.identityKey).inserted {
            unique.append(declaration)
        }
        return unique
    }

    private static func declarationSort(
        _ left: ClientComponentDeclaration,
        _ right: ClientComponentDeclaration
    ) -> Bool {
        if left.typeName != right.typeName {
            return left.typeName < right.typeName
        }
        if left.loadPolicy != right.loadPolicy {
            return left.loadPolicy < right.loadPolicy
        }
        return left.identityKey < right.identityKey
    }

    private static func visit(_ node: Syntax, body: (Syntax) -> Void) {
        body(node)
        for child in node.children(viewMode: .sourceAccurate) {
            visit(child, body: body)
        }
    }

    private static let loadPolicies: [LoadPolicy] = [
        .eager,
        .visible,
        .interaction,
        .idle,
        .manual,
    ]

    private struct ParsedFile {
        let url: URL
        let relativePath: String
        let syntax: SourceFileSyntax
    }
}
