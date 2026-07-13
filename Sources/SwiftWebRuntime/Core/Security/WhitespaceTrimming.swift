/// Trims leading/trailing whitespace without `CharacterSet`.
///
/// `CharacterSet.whitespacesAndNewlines` is declared by both Foundation and
/// FoundationEssentials on Linux, and transitive module loading makes the
/// member lookup ambiguous there — so security policies trim with a plain
/// `Character.isWhitespace` scan instead.
extension StringProtocol {
    func trimmedWhitespace() -> String {
        var slice = self[...]
        while let first = slice.first, first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice = slice.dropLast()
        }
        return String(slice)
    }
}
