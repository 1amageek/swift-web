import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation
import SwiftParser
import SwiftSyntax

package struct SwiftWebDevSwiftFileClassification: Sendable, Equatable {
    package let clientComponentTypeNames: Set<String>
    package let hasServerRuntimeSurface: Bool
}

package struct SwiftWebDevSwiftFileClassifier: Sendable {
    package static func classify(url: URL) throws -> SwiftWebDevSwiftFileClassification {
        let source = try String(contentsOf: url, encoding: .utf8)
        return classify(source: source)
    }

    package static func classify(source: String) -> SwiftWebDevSwiftFileClassification {
        let syntax = Parser.parse(source: source)
        var clientComponentTypeNames = Set<String>()
        var hasServerRuntimeSurface = false

        visit(Syntax(syntax)) { node in
            if let attribute = node.as(AttributeSyntax.self),
               isServerRuntimeAttribute(attribute.attributeName.trimmedDescription)
            {
                hasServerRuntimeSurface = true
            }

            if let declaration = node.as(StructDeclSyntax.self) {
                if inheritsClientComponent(declaration.inheritanceClause) {
                    clientComponentTypeNames.insert(declaration.name.text)
                }
                if inheritsServerRuntimeSurface(declaration.inheritanceClause) {
                    hasServerRuntimeSurface = true
                }
            }

            if let declaration = node.as(ClassDeclSyntax.self) {
                if inheritsClientComponent(declaration.inheritanceClause) {
                    clientComponentTypeNames.insert(declaration.name.text)
                }
                if inheritsServerRuntimeSurface(declaration.inheritanceClause) {
                    hasServerRuntimeSurface = true
                }
            }

            if let declaration = node.as(ActorDeclSyntax.self) {
                if inheritsClientComponent(declaration.inheritanceClause) {
                    clientComponentTypeNames.insert(declaration.name.text)
                }
                if declaration.modifiers.contains(where: { $0.name.text == "distributed" })
                    || inheritsServerRuntimeSurface(declaration.inheritanceClause)
                {
                    hasServerRuntimeSurface = true
                }
            }

            if let declaration = node.as(ExtensionDeclSyntax.self),
               let typeName = canonicalTypeName(declaration.extendedType.trimmedDescription)
            {
                if inheritsClientComponent(declaration.inheritanceClause) {
                    clientComponentTypeNames.insert(typeName)
                }
                if inheritsServerRuntimeSurface(declaration.inheritanceClause) {
                    hasServerRuntimeSurface = true
                }
            }
        }

        return SwiftWebDevSwiftFileClassification(
            clientComponentTypeNames: clientComponentTypeNames,
            hasServerRuntimeSurface: hasServerRuntimeSurface
        )
    }

    private static func inheritsClientComponent(_ inheritanceClause: InheritanceClauseSyntax?) -> Bool {
        inheritsAny(inheritanceClause, in: ["ClientComponent"])
    }

    private static func inheritsServerRuntimeSurface(_ inheritanceClause: InheritanceClauseSyntax?) -> Bool {
        inheritsAny(inheritanceClause, in: serverRuntimeInheritedTypes)
    }

    private static func inheritsAny(
        _ inheritanceClause: InheritanceClauseSyntax?,
        in candidates: Set<String>
    ) -> Bool {
        guard let inheritanceClause else {
            return false
        }

        return inheritanceClause.inheritedTypes.contains { inheritedType in
            guard let typeName = canonicalTypeName(inheritedType.type.trimmedDescription) else {
                return false
            }
            return candidates.contains(typeName)
        }
    }

    private static func isServerRuntimeAttribute(_ name: String) -> Bool {
        guard let typeName = canonicalTypeName(name) else {
            return false
        }
        return serverRuntimeAttributes.contains(typeName)
    }

    private static func canonicalTypeName(_ source: String) -> String? {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix(".") else {
            return nil
        }

        if let genericStart = value.firstIndex(of: "<") {
            value = String(value[..<genericStart])
        }

        if value.hasSuffix(".self") {
            value.removeLast(".self".count)
        }

        if let lastComponent = value.split(separator: ".").last {
            value = String(lastComponent)
        }

        guard value.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    private static func visit(_ node: Syntax, body: (Syntax) -> Void) {
        body(node)
        for child in node.children(viewMode: .sourceAccurate) {
            visit(child, body: body)
        }
    }

    private static let serverRuntimeAttributes: Set<String> = [
        "Page",
        "ServerAction",
    ]

    private static let serverRuntimeInheritedTypes: Set<String> = [
        "App",
        "Scene",
        "FormAction",
        "ServerComponent",
        "SocketPage",
        "SSERoute",
        "StreamingPage",
        "StreamPage",
        "UploadPage",
    ]
}
