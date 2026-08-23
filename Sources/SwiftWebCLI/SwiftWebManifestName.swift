enum SwiftWebManifestName {
    static func isValid(_ name: String) -> Bool {
        guard let first = name.utf8.first,
            (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(first)
        else {
            return false
        }
        return name.utf8.allSatisfy { byte in
            (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || byte == UInt8(ascii: "-")
        }
    }
}
