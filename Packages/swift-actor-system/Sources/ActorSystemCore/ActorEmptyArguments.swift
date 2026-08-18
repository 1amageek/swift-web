public struct ActorEmptyArguments: ActorPortableValue, Hashable, Sendable {
    public init() {}

    public func encodeActorValue() throws -> ActorByteBuffer {
        ActorByteBuffer()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> ActorEmptyArguments {
        guard payload.isEmpty else {
            throw ActorSystemError.decodingFailed
        }
        return ActorEmptyArguments()
    }
}

public struct ActorVoidResult: ActorPortableValue, Hashable, Sendable {
    public init() {}

    public func encodeActorValue() throws -> ActorByteBuffer {
        ActorByteBuffer()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> ActorVoidResult {
        guard payload.isEmpty else {
            throw ActorSystemError.decodingFailed
        }
        return ActorVoidResult()
    }
}
