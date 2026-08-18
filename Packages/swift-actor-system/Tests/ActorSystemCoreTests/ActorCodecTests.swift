import ActorSystemCore
import Testing

@Suite
struct ActorCodecTests {
    @Test
    func frameRoundTripsWithoutChangingWireFields() throws {
        let codec = ActorFrameCodec(
            maximumFrameBytes: 4_096,
            maximumPayloadBytes: 2_048,
            maximumIdentityBytes: 128
        )
        let frame = ActorFrame.invocation(
            ActorInvocationFrame(
                callID: ActorCallID(session: ActorSessionID(1), sequence: 2),
                invocation: ActorInvocation(
                    recipient: ActorAddress(
                        type: ActorTypeID(high: 3, low: 4),
                        identity: "counter-😀"
                    ),
                    method: ActorMethodID(5),
                    schemaFingerprint: ActorSchemaFingerprint(high: 6, low: 7),
                    payload: try [1, 2, 3].encodeActorValue()
                ),
                remainingTimeoutNanoseconds: 8
            )
        )

        #expect(try codec.decode(codec.encode(frame)) == frame)
    }

    @Test
    func frameDecoderRejectsTruncationAndInvalidUtf8() throws {
        let codec = ActorFrameCodec(
            maximumFrameBytes: 4_096,
            maximumPayloadBytes: 2_048,
            maximumIdentityBytes: 128
        )
        let frame = ActorFrame.invocation(
            ActorInvocationFrame(
                callID: ActorCallID(session: ActorSessionID(1), sequence: 2),
                invocation: ActorInvocation(
                    recipient: ActorAddress(
                        type: ActorTypeID(high: 3, low: 4),
                        identity: "a"
                    ),
                    method: ActorMethodID(5),
                    schemaFingerprint: ActorSchemaFingerprint(high: 6, low: 7),
                    payload: ActorByteBuffer()
                ),
                remainingTimeoutNanoseconds: nil
            )
        )
        let encoded = try codec.encode(frame)
        let truncated = encoded.slice(0..<(encoded.count - 1))
        #expect(throws: ActorSystemError.self) {
            try codec.decode(truncated)
        }

        var invalidBytes = encoded.bytes
        invalidBytes[48] = 0xFF
        #expect(throws: ActorSystemError.self) {
            try codec.decode(ActorByteBuffer(invalidBytes))
        }
    }

    @Test
    func frameCodecReservesZeroSequenceForHello() throws {
        let codec = ActorFrameCodec(
            maximumFrameBytes: 4_096,
            maximumPayloadBytes: 2_048,
            maximumIdentityBytes: 128
        )
        let invocation = ActorFrame.invocation(
            ActorInvocationFrame(
                callID: ActorCallID(session: ActorSessionID(1), sequence: 0),
                invocation: ActorInvocation(
                    recipient: ActorAddress(
                        type: ActorTypeID(high: 3, low: 4),
                        identity: "counter"
                    ),
                    method: ActorMethodID(5),
                    schemaFingerprint: ActorSchemaFingerprint(high: 6, low: 7),
                    payload: ActorByteBuffer()
                ),
                remainingTimeoutNanoseconds: nil
            )
        )

        #expect(throws: ActorSystemError.self) {
            _ = try codec.encode(invocation)
        }
        #expect(
            try codec.decode(
                codec.encode(
                    .hello(
                        ActorHelloFrame(
                            session: ActorSessionID(1),
                            maximumWireVersion: ActorFrameCodec.wireVersion
                        )
                    )
                )
            ) == .hello(
                ActorHelloFrame(
                    session: ActorSessionID(1),
                    maximumWireVersion: ActorFrameCodec.wireVersion
                )
            )
        )
    }

    @Test
    func actorDescriptorRejectsDuplicateMethodIDs() throws {
        let method = ActorMethodDescriptor(
            id: ActorMethodID(1),
            parameterTypeIDs: [],
            resultTypeID: nil,
            errorTypeID: nil
        )
        let descriptor = ActorTypeDescriptor(
            id: ActorTypeID(high: 1, low: 2),
            schemaFingerprint: ActorSchemaFingerprint(high: 3, low: 4),
            methods: [method, method]
        )

        #expect(throws: ActorSystemError.self) {
            try descriptor.validate()
        }
    }

    @Test
    func dictionaryEncodingIsCanonicalAcrossInsertionOrder() throws {
        var first: [String: Int] = [:]
        first["b"] = 2
        first["a"] = 1
        var second: [String: Int] = [:]
        second["a"] = 1
        second["b"] = 2

        let firstPayload = try first.encodeActorValue()
        let secondPayload = try second.encodeActorValue()
        #expect(firstPayload == secondPayload)
        #expect(
            try [String: Int].decodeActorValue(
                from: firstPayload,
                options: .init()
            ) == first
        )
    }

    @Test
    func payloadDecoderRejectsDuplicateFields() throws {
        var bytes = ActorPayloadEncoder()
        try bytes.append(1, field: ActorFieldID(1))
        let field = bytes.finish()
        let duplicate = ActorByteBuffer(field.bytes + field.bytes)
        var decoder = try ActorPayloadDecoder(
            duplicate,
            maximumCollectionElements: 2,
            maximumNestingDepth: 4
        )
        _ = try decoder.nextField()
        #expect(throws: ActorSystemError.self) {
            _ = try decoder.nextField()
        }
    }

    @Test
    func nestedPortableValuesCannotResetDepthLimit() throws {
        let value = [[[1]]]
        let payload = try value.encodeActorValue()

        #expect(throws: ActorSystemError.self) {
            _ = try [[[Int]]].decodeActorValue(
                from: payload,
                options: ActorPortableDecodingOptions(
                    maximumCollectionElements: 16,
                    maximumNestingDepth: 2
                )
            )
        }
    }
}
