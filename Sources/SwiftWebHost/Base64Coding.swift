/// Standard-alphabet Base64 (RFC 4648 §4, with padding). One implementation
/// for every profile so token generation is identical with or without
/// Foundation.
public enum Base64Coding {

    public static func decode(_ string: String) -> [UInt8]? {
        var values: [UInt8] = []
        values.reserveCapacity(string.utf8.count)
        var padding = 0
        for byte in string.utf8 {
            if byte == UInt8(ascii: "=") {
                padding += 1
                continue
            }
            guard padding == 0, let value = sextet(byte) else {
                return nil
            }
            values.append(value)
        }
        guard (values.count + padding) % 4 == 0, padding <= 2 else {
            return nil
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(values.count * 3 / 4)
        var index = 0
        while index + 4 <= values.count {
            let chunk = (UInt32(values[index]) << 18) | (UInt32(values[index + 1]) << 12)
                | (UInt32(values[index + 2]) << 6) | UInt32(values[index + 3])
            bytes.append(UInt8((chunk >> 16) & 0xFF))
            bytes.append(UInt8((chunk >> 8) & 0xFF))
            bytes.append(UInt8(chunk & 0xFF))
            index += 4
        }
        let remaining = values.count - index
        if remaining == 3 {
            let chunk = (UInt32(values[index]) << 18) | (UInt32(values[index + 1]) << 12) | (UInt32(values[index + 2]) << 6)
            bytes.append(UInt8((chunk >> 16) & 0xFF))
            bytes.append(UInt8((chunk >> 8) & 0xFF))
        } else if remaining == 2 {
            let chunk = (UInt32(values[index]) << 18) | (UInt32(values[index + 1]) << 12)
            bytes.append(UInt8((chunk >> 16) & 0xFF))
        } else if remaining == 1 {
            return nil
        }
        return bytes
    }

    private static func sextet(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"):
            byte - UInt8(ascii: "A")
        case UInt8(ascii: "a")...UInt8(ascii: "z"):
            byte - UInt8(ascii: "a") + 26
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            byte - UInt8(ascii: "0") + 52
        case UInt8(ascii: "+"):
            62
        case UInt8(ascii: "/"):
            63
        default:
            nil
        }
    }

    private static let alphabet: [Character] = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    )

    public static func encode(_ bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity((bytes.count + 2) / 3 * 4)
        var index = 0
        while index + 3 <= bytes.count {
            let chunk = (UInt32(bytes[index]) << 16) | (UInt32(bytes[index + 1]) << 8) | UInt32(bytes[index + 2])
            result.append(alphabet[Int((chunk >> 18) & 0x3F)])
            result.append(alphabet[Int((chunk >> 12) & 0x3F)])
            result.append(alphabet[Int((chunk >> 6) & 0x3F)])
            result.append(alphabet[Int(chunk & 0x3F)])
            index += 3
        }
        let remaining = bytes.count - index
        if remaining == 1 {
            let chunk = UInt32(bytes[index]) << 16
            result.append(alphabet[Int((chunk >> 18) & 0x3F)])
            result.append(alphabet[Int((chunk >> 12) & 0x3F)])
            result.append("==")
        } else if remaining == 2 {
            let chunk = (UInt32(bytes[index]) << 16) | (UInt32(bytes[index + 1]) << 8)
            result.append(alphabet[Int((chunk >> 18) & 0x3F)])
            result.append(alphabet[Int((chunk >> 12) & 0x3F)])
            result.append(alphabet[Int((chunk >> 6) & 0x3F)])
            result.append("=")
        }
        return result
    }
}
