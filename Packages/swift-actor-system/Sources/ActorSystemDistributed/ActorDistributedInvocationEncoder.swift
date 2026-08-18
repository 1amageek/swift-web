import ActorSystemCore
import Distributed

public struct ActorDistributedInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = Codable & Sendable

    private enum State: Sendable {
        case recording
        case finished
        case consumed
    }

    private let binaryEncoder: ActorBinaryEncoder
    private var state: State = .recording
    private var arguments: [ActorByteBuffer] = []

    public init(registry: ActorDistributedCodecRegistry) {
        self.binaryEncoder = ActorBinaryEncoder(registry: registry)
    }

    init(
        prepareEncoding: @escaping @Sendable (
            ObjectIdentifier
        ) throws -> ActorDistributedCodecRegistry.PreparedEncoding
    ) {
        self.binaryEncoder = ActorBinaryEncoder(
            prepareEncoding: prepareEncoding
        )
    }

    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
        throw ActorSystemError.encodingFailed
    }

    public mutating func recordArgument<Value>(
        _ argument: RemoteCallArgument<Value>
    ) throws where Value: Codable & Sendable {
        guard state == .recording else {
            throw ActorSystemError.encodingFailed
        }
        arguments.append(try binaryEncoder.encode(argument.value))
    }

    public mutating func recordReturnType<R>(
        _ type: R.Type
    ) throws where R: Codable & Sendable {
        guard state == .recording else {
            throw ActorSystemError.encodingFailed
        }
    }

    public mutating func recordErrorType<E>(_ type: E.Type) throws where E: Error {
        guard state == .recording else {
            throw ActorSystemError.encodingFailed
        }
    }

    public mutating func doneRecording() throws {
        guard state == .recording else {
            throw ActorSystemError.encodingFailed
        }
        state = .finished
    }

    mutating func consumePayload() throws -> ActorByteBuffer {
        guard state == .finished else {
            throw ActorSystemError.encodingFailed
        }
        state = .consumed
        return try ActorArgumentListCodec.encode(arguments)
    }
}
