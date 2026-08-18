import SwiftSyntax

enum ActorPortableDefaultExpressionValidator {
    static func validate(
        _ expression: ExprSyntax,
        symbol: String,
        declaration: String
    ) throws {
        guard expression.tokens(viewMode: .sourceAccurate).allSatisfy(isPortableToken) else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "\(declaration) default values must be self-contained literals for portable generation"
            )
        }
    }

    private static func isPortableToken(_ token: TokenSyntax) -> Bool {
        switch token.tokenKind {
        case .integerLiteral,
             .floatLiteral,
             .stringQuote,
             .multilineStringQuote,
             .stringSegment,
             .rawStringPoundDelimiter,
             .leftParen,
             .rightParen,
             .leftSquare,
             .rightSquare,
             .comma,
             .colon,
             .endOfFile:
            return true
        case .keyword(.true), .keyword(.false), .keyword(.nil):
            return true
        case .prefixOperator(let operation):
            return operation == "+" || operation == "-"
        default:
            return false
        }
    }
}
