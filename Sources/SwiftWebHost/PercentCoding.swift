/// Percent-encoding for generated route URLs. The allowed sets mirror
/// Foundation's `urlPathAllowed`/`urlQueryAllowed` so links render the same
/// bytes as `URLComponents`-built ones, with two deliberate deviations for
/// round-trip correctness: `/` is escaped inside a path *segment* (a value
/// must not create new segments), and `+`/`&`/`=` are escaped inside a query
/// component (the parser reads `+` as space and the others as separators).
package enum PercentCoding {
    /// Foundation `urlPathAllowed` minus `/`.
    private static let pathSegmentAllowed = "!$&'()*+,-.:=@_~"
    /// Foundation `urlQueryAllowed` minus `&`, `=`, `+`.
    private static let queryComponentAllowed = "!$'()*,-./:;?@_~"

    package static func encodePathSegment(_ value: String) -> String {
        encode(value, allowed: pathSegmentAllowed)
    }

    package static func encodeQueryComponent(_ value: String) -> String {
        encode(value, allowed: queryComponentAllowed)
    }

    private static func encode(_ value: String, allowed: String) -> String {
        var result = ""
        result.reserveCapacity(value.utf8.count)
        let allowedBytes = Set(allowed.utf8)
        for byte in value.utf8 {
            let isUnreservedAlphanumeric =
                (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
                || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
                || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            if isUnreservedAlphanumeric || allowedBytes.contains(byte) {
                result.append(Character(UnicodeScalar(byte)))
            } else {
                result.append("%")
                result.append(hexDigit(byte >> 4))
                result.append(hexDigit(byte & 0x0F))
            }
        }
        return result
    }

    private static func hexDigit(_ value: UInt8) -> Character {
        let digits: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
        return digits[Int(value)]
    }
}
