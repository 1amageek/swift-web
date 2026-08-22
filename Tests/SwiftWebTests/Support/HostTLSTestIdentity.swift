import TLS

enum HostTLSTestIdentity {
    static func serverConfiguration() -> TLSConfiguration {
        TLSConfiguration.server(
            identity: TLSIdentity(
                privateKey: [UInt8](repeating: 0, count: 31) + [0x01],
                keyType: .ecdsaP256,
                certificateChain: [Certificate(der: certificateDER())]
            ),
            alpn: ["http/1.1"]
        )
    }

    private static func certificateDER() -> [UInt8] {
        let encoded =
            "3082016930820110a003020102020107300a06082a8648ce3d04030230223120301e"
            + "06035504030c1773776966742d73736c2d65636473612e6578616d706c65301e170d"
            + "3235303130313030303030305a170d3335303130313030303030305a30223120301e"
            + "06035504030c1773776966742d73736c2d65636473612e6578616d706c6530593013"
            + "06072a8648ce3d020106082a8648ce3d030107034200046b17d1f2e12c4247f8bce6e"
            + "563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f"
            + "9e162bce33576b315ececbb6406837bf51f5a3373035300f0603551d130101ff0405"
            + "30030101ff30220603551d11041b3019821773776966742d73736c2d65636473612e"
            + "6578616d706c65300a06082a8648ce3d040302034700304402207d64b4f0d8d41a49"
            + "720e591dc1844556462cd8beb44558fa9f63156a76f2c6cc022063756eb89655ab0b"
            + "0b04032d184382dd99e0be5ce5cacc66374a36dc83f7ac23"

        var bytes: [UInt8] = []
        bytes.reserveCapacity(encoded.count / 2)
        var index = encoded.startIndex
        while index < encoded.endIndex {
            let next = encoded.index(index, offsetBy: 2)
            bytes.append(UInt8(encoded[index..<next], radix: 16)!)
            index = next
        }
        return bytes
    }
}
