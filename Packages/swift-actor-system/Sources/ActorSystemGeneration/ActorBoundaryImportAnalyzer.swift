import Foundation

public enum ActorBoundaryImportAnalyzer {
    public static func importedModules(
        actors: [ActorSourceModel],
        sourceFiles: [URL],
        moduleName: String,
        targetEnvironment: ActorGenerationTargetEnvironment? = nil
    ) throws -> Set<String> {
        let rootValueTypes = Set(actors.flatMap { actor in
            actor.methods.flatMap { method in
                method.parameters.map(\.type)
                    + (isVoid(method.returnType) ? [] : [method.returnType])
                    + (typedErrorType(method.throwsClause).map { [$0] } ?? [])
            }
        })
        let portableTypes = try ActorPortableTypeScanner.scan(
            sourceFiles: sourceFiles,
            moduleName: moduleName,
            reachableFrom: rootValueTypes,
            targetEnvironment: targetEnvironment
        )
        return Set(actors.flatMap(\.imports) + portableTypes.flatMap(\.imports))
    }

    private static func isVoid(_ type: String) -> Bool {
        type == "Void" || type == "()" || type == "Swift.Void"
    }

    private static func typedErrorType(_ throwsClause: String?) -> String? {
        guard let throwsClause,
              let open = throwsClause.firstIndex(of: "("),
              let close = throwsClause.lastIndex(of: ")"),
              open < close
        else {
            return nil
        }
        return String(throwsClause[throwsClause.index(after: open)..<close])
    }
}
