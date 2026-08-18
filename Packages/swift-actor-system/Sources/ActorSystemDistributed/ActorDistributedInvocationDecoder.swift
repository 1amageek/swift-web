import ActorSystemCore
import Distributed

public struct ActorDistributedInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = Codable & Sendable

    private let binaryDecoder: ActorBinaryDecoder
    private var arguments: [ActorByteBuffer]
    private var nextArgumentIndex = 0

    public init(
        payload: ActorByteBuffer,
        registry: ActorDistributedCodecRegistry,
        maximumArgumentCount: Int,
        maximumNestingDepth: Int
    ) throws {
        let options = ActorPortableDecodingOptions(
            maximumCollectionElements: maximumArgumentCount,
            maximumNestingDepth: maximumNestingDepth
        )
        self.binaryDecoder = ActorBinaryDecoder(
            registry: registry,
            options: try options.descending()
        )
        self.arguments = try ActorArgumentListCodec.decode(
            payload,
            maximumArgumentCount: maximumArgumentCount,
            maximumNestingDepth: maximumNestingDepth
        )
    }

    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
        []
    }

    public mutating func decodeNextArgument<Argument>() throws -> Argument
    where Argument: Codable & Sendable {
        guard nextArgumentIndex < arguments.count else {
            throw ActorSystemError.decodingFailed
        }
        let payload = arguments[nextArgumentIndex]
        nextArgumentIndex += 1
        return try binaryDecoder.decode(Argument.self, from: payload)
    }

    public mutating func decodeReturnType() throws -> Any.Type? {
        nil
    }

    public mutating func decodeErrorType() throws -> Any.Type? {
        nil
    }

    mutating func requireExhausted() throws {
        guard nextArgumentIndex == arguments.count else {
            throw ActorSystemError.decodingFailed
        }
    }
}
