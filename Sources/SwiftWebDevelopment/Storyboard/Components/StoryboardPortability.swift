import SwiftHTML

/// Formats a finite catalog control value without Foundation's printf bridge.
func storyboardFixedDecimal(_ value: Double, fractionDigits: Int) -> String {
    precondition(fractionDigits >= 0 && fractionDigits <= 9)
    var scale = 1
    for _ in 0..<fractionDigits {
        scale *= 10
    }

    let scaled = Int((value * Double(scale)).rounded())
    if fractionDigits == 0 {
        return String(scaled)
    }

    let negative = scaled < 0
    let magnitude = negative ? -scaled : scaled
    let whole = magnitude / scale
    let fraction = String(magnitude % scale)
    let padding = String(repeating: "0", count: fractionDigits - fraction.count)
    return "\(negative ? "-" : "")\(whole).\(padding)\(fraction)"
}

func storyboardShortestDecimal(_ value: Double) -> String {
    if value == value.rounded() {
        return String(Int(value))
    }
    return String(value)
}

func storyboardPaddedInteger(_ value: Int, width: Int) -> String {
    let digits = String(value)
    guard digits.count < width else { return digits }
    return String(repeating: "0", count: width - digits.count) + digits
}

func storyboardFirstRange(
    in source: Substring,
    of needle: String
) -> Range<String.Index>? {
    guard !needle.isEmpty else { return source.startIndex..<source.startIndex }
    var candidate = source.startIndex
    while candidate < source.endIndex {
        if source[candidate...].hasPrefix(needle) {
            let upperBound = source.index(candidate, offsetBy: needle.count)
            return candidate..<upperBound
        }
        candidate = source.index(after: candidate)
    }
    return nil
}

func storyboardLastRange(in source: String, of needle: String) -> Range<String.Index>? {
    var remainder = source[...]
    var lastMatch: Range<String.Index>?
    while let match = storyboardFirstRange(in: remainder, of: needle) {
        lastMatch = match
        remainder = source[match.upperBound...]
    }
    return lastMatch
}

func storyboardContains(_ source: String, _ needle: String) -> Bool {
    storyboardFirstRange(in: source[...], of: needle) != nil
}

func storyboardRemovingRuntimeAttributes(from html: String) -> String {
    var output = ""
    var cursor = html.startIndex
    while cursor < html.endIndex {
        if html[cursor] == " " {
            let attributeStart = html.index(after: cursor)
            if let attributeEnd = storyboardRuntimeAttributeEnd(
                in: html,
                from: attributeStart
            ) {
                cursor = attributeEnd
                continue
            }
        }
        output.append(html[cursor])
        cursor = html.index(after: cursor)
    }
    return output
}

private func storyboardRuntimeAttributeEnd(
    in html: String,
    from start: String.Index
) -> String.Index? {
    let remainder = html[start...]
    if remainder.hasPrefix("data-node=\"") {
        return storyboardQuotedAttributeEnd(in: html, from: start)
    }
    guard remainder.hasPrefix("data-event-") else { return nil }

    var cursor = html.index(start, offsetBy: "data-event-".count)
    let nameStart = cursor
    while cursor < html.endIndex, storyboardIsASCIILowercase(html[cursor]) {
        cursor = html.index(after: cursor)
    }
    guard cursor > nameStart, html[cursor...].hasPrefix("=\"") else { return nil }
    return storyboardQuotedAttributeEnd(in: html, from: start)
}

private func storyboardQuotedAttributeEnd(
    in html: String,
    from start: String.Index
) -> String.Index? {
    guard let openingQuote = html[start...].firstIndex(of: "\"") else { return nil }
    let valueStart = html.index(after: openingQuote)
    guard let closingQuote = html[valueStart...].firstIndex(of: "\"") else { return nil }
    return html.index(after: closingQuote)
}

private func storyboardIsASCIILowercase(_ character: Character) -> Bool {
    "abcdefghijklmnopqrstuvwxyz".contains(character)
}
