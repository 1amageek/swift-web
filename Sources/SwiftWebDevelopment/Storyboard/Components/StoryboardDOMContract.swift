import Foundation
import SwiftHTML

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
