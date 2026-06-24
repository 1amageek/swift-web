import SwiftHTML

public struct Code: WebUIAttributeComponent {
    private let source: String
    private let language: String?
    private let startLine: Int
    private let showsLineNumbers: Bool
    private let attributes: [HTMLAttribute]

    public init(
        language: String? = nil,
        startLine: Int = 1,
        showsLineNumbers: Bool = true,
        _ attributes: HTMLAttribute...,
        @StringBuilder content: () -> String
    ) {
        self.source = content()
        self.language = language
        self.startLine = startLine
        self.showsLineNumbers = showsLineNumbers
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("pre", attributes: mergedAttributes(class: "swui-code-block", extra: codeBlockAttributes)) {
            Element("code", attributes: codeAttributes) {
                ForEach(lines, id: \.number) { line in
                    span(.class(lineClass), .data("line", String(line.number))) {
                        if showsLineNumbers {
                            span(.class("swui-code-line-number"), .aria("hidden", "true")) {
                                String(line.number)
                            }
                        }
                        span(.class("swui-code-line-content")) {
                            // Preserve the height of a blank line (matches the design).
                            line.text.isEmpty ? " " : line.text
                        }
                    }
                }
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            source,
            language: language,
            startLine: startLine,
            showsLineNumbers: showsLineNumbers,
            attributes: self.attributes + attributes
        )
    }

    private init(
        _ code: String,
        language: String?,
        startLine: Int,
        showsLineNumbers: Bool,
        attributes: [HTMLAttribute]
    ) {
        self.source = code
        self.language = language
        self.startLine = startLine
        self.showsLineNumbers = showsLineNumbers
        self.attributes = attributes
    }

    private var codeBlockAttributes: [HTMLAttribute] {
        [
            .role("region"),
            .aria("label", language.map { "\($0) code block" } ?? "Code block"),
        ] + attributes
    }

    private var codeAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [.class("swui-code-block-content")]
        if let language {
            result.append(.data("language", language))
        }
        return result
    }

    private var lineClass: String {
        showsLineNumbers ? "swui-code-line" : "swui-code-line swui-code-line-plain"
    }

    private var lines: [CodeLine] {
        let normalizedLines = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                if line.last == "\r" {
                    return String(line.dropLast())
                }
                return String(line)
            }

        let sourceLines = normalizedLines.isEmpty ? [""] : normalizedLines
        return sourceLines.enumerated().map { index, text in
            CodeLine(number: startLine + index, text: text)
        }
    }
}

private struct CodeLine: Sendable {
    let number: Int
    let text: String
}
