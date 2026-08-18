enum ActorMethodEffectValidator {
    static let typedThrowsReason =
        "Typed throws cannot preserve ActorSystemError without changing the authored method surface; use untyped throws for portable actors"

    static func validatePortableActorContract(
        _ actors: [ActorSourceModel]
    ) throws {
        for actor in actors {
            for method in actor.methods where isTypedThrows(method.throwsClause) {
                throw ActorGenerationError.unsupportedDeclaration(
                    symbol: "\(actor.symbol).\(method.name)",
                    reason: typedThrowsReason
                )
            }
        }
    }

    private static func isTypedThrows(_ throwsClause: String?) -> Bool {
        guard let throwsClause else {
            return false
        }
        return throwsClause.contains("(") && throwsClause.contains(")")
    }
}
