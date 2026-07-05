import SwiftParser
import SwiftSyntax

/// Removes SwiftHTML preview declarations (`#Preview { ... }`, and the legacy
/// `#HTMLPreview { ... }`) from copied client component sources so generated
/// browser WASM packages compile without the SwiftHTML preview macro (a
/// host-only Xcode tool).
///
/// SwiftHTML's `#Preview` is a freestanding declaration macro declared only
/// where WebKit is available. The vendored WASM copy of `SwiftHTML` omits that
/// declaration, so any `#Preview` left in a mirrored page source would fail to
/// resolve. The preview has no client-side meaning, so it is stripped.
enum SwiftWebClientPreviewStripper {
    static func stripHTMLPreview(inSource source: String) -> String {
        guard source.contains("Preview") else {
            return source
        }
        let file = Parser.parse(source: source)
        let rewriter = PreviewStripRewriter()
        let rewritten = rewriter.visit(file)
        guard rewriter.didStrip else {
            return source
        }
        return rewritten.description
    }
}

private final class PreviewStripRewriter: SyntaxRewriter {
    private(set) var didStrip = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: CodeBlockItemListSyntax) -> CodeBlockItemListSyntax {
        let filtered = node.filter { !isHTMLPreview($0.item) }
        if filtered.count != node.count {
            didStrip = true
        }
        return super.visit(CodeBlockItemListSyntax(filtered))
    }

    override func visit(_ node: MemberBlockItemListSyntax) -> MemberBlockItemListSyntax {
        let filtered = node.filter { !isHTMLPreview($0.decl) }
        if filtered.count != node.count {
            didStrip = true
        }
        return super.visit(MemberBlockItemListSyntax(filtered))
    }

    private static let previewMacroNames: Set<String> = ["Preview", "HTMLPreview"]

    private func isHTMLPreview(_ item: CodeBlockItemSyntax.Item) -> Bool {
        switch item {
        case .decl(let decl):
            return isHTMLPreview(decl)
        case .expr(let expr):
            guard let name = expr.as(MacroExpansionExprSyntax.self)?.macroName.text else {
                return false
            }
            return Self.previewMacroNames.contains(name)
        default:
            return false
        }
    }

    private func isHTMLPreview(_ decl: DeclSyntax) -> Bool {
        guard let name = decl.as(MacroExpansionDeclSyntax.self)?.macroName.text else {
            return false
        }
        return Self.previewMacroNames.contains(name)
    }
}
