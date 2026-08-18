enum ActorStableHash {
    static func hash64(_ value: String, seed: UInt64 = 0xcbf29ce484222325) -> UInt64 {
        var hash = seed
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    static func hash128(_ value: String) -> ActorSchemaLockID128 {
        ActorSchemaLockID128(
            high: hash64(value, seed: 0x6c62272e07bb0142),
            low: hash64(value, seed: 0x62b821756295c58d)
        )
    }

    static func digest(_ value: String) -> String {
        let hash = hash128(value)
        return hexadecimal(hash.high) + hexadecimal(hash.low)
    }

    private static func hexadecimal(_ value: UInt64) -> String {
        let encoded = String(value, radix: 16, uppercase: false)
        return String(repeating: "0", count: 16 - encoded.count) + encoded
    }
}
