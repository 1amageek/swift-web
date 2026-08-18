public enum ActorArgumentListCodec {
    public static func encode(_ arguments: [ActorByteBuffer]) throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        for (index, argument) in arguments.enumerated() {
            guard let fieldID = UInt32(exactly: index + 1) else {
                throw ActorSystemError.encodingFailed
            }
            try encoder.append(
                message: argument,
                field: ActorFieldID(fieldID)
            )
        }
        return encoder.finish()
    }

    public static func decode(
        _ payload: ActorByteBuffer,
        maximumArgumentCount: Int,
        maximumNestingDepth: Int
    ) throws -> [ActorByteBuffer] {
        var decoder = try ActorPayloadDecoder(
            payload,
            maximumCollectionElements: maximumArgumentCount,
            maximumNestingDepth: maximumNestingDepth
        )
        var arguments: [ActorByteBuffer] = []
        while let field = try decoder.nextField() {
            guard let expectedID = UInt32(exactly: arguments.count + 1) else {
                throw ActorSystemError.decodingFailed
            }
            guard field.id.rawValue == expectedID, field.wireType == .message else {
                throw ActorSystemError.decodingFailed
            }
            arguments.append(field.payloadBuffer())
        }
        return arguments
    }
}
