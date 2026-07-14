/// The single query-string/form parser every host shares, so `?a=b` means the
/// same thing on every runtime: pairs split on `&`, the first `=` separates
/// name from value, names and values form-unescape (`+` → space, `%XX` → byte,
/// malformed escapes kept literally — WHATWG parsing), repeated names keep
/// wire order. Pure Swift; compiles on every profile including Embedded.
enum FormParsing {
    /// Parses `a=1&b=two+words&b=3` into `["a": ["1"], "b": ["two words", "3"]]`.
    static func parse(_ encoded: String) -> [String: [String]] {
        var fields: [String: [String]] = [:]
        for pair in encoded.split(separator: "&", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawName = parts.first, !rawName.isEmpty else {
                continue
            }
            let name = Self.formUnescape(String(rawName))
            let value = parts.count > 1 ? Self.formUnescape(String(parts[1])) : ""
            fields[name, default: []].append(value)
        }
        return fields
    }

    /// Form unescaping (`+` → space, `%XX` → byte). Malformed escapes are kept
    /// literally, like browsers do.
    static func formUnescape(_ string: String) -> String {
        unescape(string, plusMeansSpace: true)
    }

    /// RFC 3986 percent-decoding for path segments (`+` stays literal).
    /// Malformed escapes are kept literally.
    static func percentDecode(_ string: String) -> String {
        unescape(string, plusMeansSpace: false)
    }

    private static func unescape(_ string: String, plusMeansSpace: Bool) -> String {
        let utf8 = Array(string.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(utf8.count)
        var index = 0
        while index < utf8.count {
            let byte = utf8[index]
            if plusMeansSpace, byte == UInt8(ascii: "+") {
                bytes.append(UInt8(ascii: " "))
                index += 1
            } else if byte == UInt8(ascii: "%"),
                      index + 2 < utf8.count,
                      let high = hexValue(utf8[index + 1]),
                      let low = hexValue(utf8[index + 2]) {
                bytes.append(high << 4 | low)
                index += 3
            } else {
                bytes.append(byte)
                index += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            byte - UInt8(ascii: "A") + 10
        default:
            nil
        }
    }
}
