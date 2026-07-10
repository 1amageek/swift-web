import Foundation
import SwiftHTML

// SwiftHTML ships a `CharacterSet` polyfill for FoundationEssentials-only hosts;
// on the WASM target both it and Foundation's are in scope, so pin the name here.
private typealias CharacterSet = Foundation.CharacterSet

/// Indents contract markup one element per line so the DOM contract reads as a
/// tree instead of a single overflowing string.
func storyboardPrettyPrintedHTML(_ html: String) -> String {
    let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "source", "track", "wbr",
    ]
    var lines: [String] = []
    var depth = 0
    var remainder = html[...]

    func append(_ text: Substring, at depth: Int) {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(String(repeating: "  ", count: max(0, depth)) + trimmed)
    }

    while let tagStart = remainder.firstIndex(of: "<") {
        append(remainder[..<tagStart], at: depth)
        guard let tagEnd = remainder[tagStart...].firstIndex(of: ">") else {
            append(remainder[tagStart...], at: depth)
            remainder = remainder[remainder.endIndex...]
            break
        }
        let tag = remainder[tagStart...tagEnd]
        let isClosing = tag.hasPrefix("</")
        let name = tag.dropFirst(isClosing ? 2 : 1)
            .prefix { $0.isLetter || $0.isNumber || $0 == "-" }
            .lowercased()
        if isClosing {
            depth -= 1
            append(tag, at: depth)
        } else {
            append(tag, at: depth)
            if !tag.hasSuffix("/>") && !voidElements.contains(name) {
                depth += 1
            }
        }
        remainder = remainder[remainder.index(after: tagEnd)...]
    }
    append(remainder, at: depth)
    return lines.joined(separator: "\n")
}

func storyboardDOMContractHTML(from html: String) -> String {
    var sanitizedHTML = html
    sanitizedHTML = sanitizedHTML.replacingOccurrences(
        of: #"\s*data-node="[^"]*""#,
        with: "",
        options: .regularExpression
    )
    sanitizedHTML = sanitizedHTML.replacingOccurrences(
        of: #"\s*data-event-[a-z]+="[^"]*""#,
        with: "",
        options: .regularExpression
    )
    return storyboardPublicClassHTML(from: sanitizedHTML)
}

private func storyboardPublicClassHTML(from html: String) -> String {
    var output = ""
    var remainder = html[...]
    let marker = #" class=""#

    while let range = remainder.range(of: marker) {
        output.append(contentsOf: remainder[..<range.lowerBound])
        let valueStart = range.upperBound
        guard let valueEnd = remainder[valueStart...].firstIndex(of: "\"") else {
            output.append(contentsOf: remainder[range.lowerBound...])
            return output
        }

        let classValue = String(remainder[valueStart..<valueEnd])
        let publicTokens = classValue
            .split(separator: " ")
            .map(String.init)
            .filter(storyboardShouldShowClassToken)

        if !publicTokens.isEmpty {
            output.append(#" class=""#)
            output.append(publicTokens.joined(separator: " "))
            output.append(#"""#)
        }
        remainder = remainder[remainder.index(after: valueEnd)...]
    }

    output.append(contentsOf: remainder)
    return output
}

private func storyboardShouldShowClassToken(_ token: String) -> Bool {
    guard !storyboardInternalClassTokens.contains(token) else { return false }
    return !storyboardIsGeneratedAtomicClass(token)
}

private let storyboardInternalClassTokens: Set<String> = [
    "swui-modifier",
    "swui-style",
    "swui-box",
    "swui-text-style",
    "swui-style-foreground",
    "swui-style-background",
    "swui-style-shaped-background",
]

private func storyboardIsGeneratedAtomicClass(_ token: String) -> Bool {
    guard token.hasPrefix("swui-"),
          let marker = token.range(of: "-x", options: .backwards) else {
        return false
    }

    let suffix = token[marker.upperBound...]
    guard suffix.count >= 8 else { return false }
    return suffix.allSatisfy { character in
        character.isNumber || ("a"..."f").contains(character) || ("A"..."F").contains(character)
    }
}
