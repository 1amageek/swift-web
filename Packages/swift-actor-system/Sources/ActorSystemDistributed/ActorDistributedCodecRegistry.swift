import ActorSystemCore
import Distributed
import Synchronization

public final class ActorDistributedCodecRegistry: Sendable {
    fileprivate struct AnyCodec: Sendable {
        let swiftTypeID: ObjectIdentifier
        let typeID: ActorTypeID
        let encode: @Sendable (any Sendable) throws -> ActorByteBuffer
        let decode: @Sendable (
            ActorByteBuffer,
            ActorPortableDecodingOptions
        ) throws -> any Sendable
    }

    fileprivate struct State: Sendable {
        var codecsBySwiftType: [ObjectIdentifier: AnyCodec] = [:]
        var codecsByTypeID: [ActorTypeID: AnyCodec] = [:]
    }

    struct PreparedEncoding: Sendable {
        let typeID: ActorTypeID
        private let encodeValue: @Sendable (any Sendable) throws -> ActorByteBuffer

        fileprivate init(codec: AnyCodec) {
            self.typeID = codec.typeID
            self.encodeValue = codec.encode
        }

        func encode(_ value: any Sendable) throws -> ActorByteBuffer {
            try encodeValue(value)
        }
    }

    private let state = Mutex(State())

    public init() {}

    private init(snapshot: State) {
        state.withLock { $0 = snapshot }
    }

    public func snapshot() -> ActorDistributedCodecRegistry {
        ActorDistributedCodecRegistry(snapshot: state.withLock { $0 })
    }

    struct Checkpoint: Sendable {
        fileprivate let state: State
    }

    func checkpoint() -> Checkpoint {
        state.withLock { Checkpoint(state: $0) }
    }

    func restore(_ checkpoint: Checkpoint) {
        state.withLock { $0 = checkpoint.state }
    }

    func validateBootstrapCodecCoverage(
        for descriptors: [ActorTypeDescriptor],
        bootstrapIdentifier: String
    ) throws {
        var requiredTypeIDs: Set<ActorTypeID> = []
        for descriptor in descriptors {
            for method in descriptor.methods {
                requiredTypeIDs.formUnion(method.parameterTypeIDs)
                if let resultTypeID = method.resultTypeID {
                    requiredTypeIDs.insert(resultTypeID)
                }
                if let errorTypeID = method.errorTypeID {
                    requiredTypeIDs.insert(errorTypeID)
                }
            }
        }
        let missing = state.withLock { state in
            requiredTypeIDs.filter { state.codecsByTypeID[$0] == nil }
        }
        guard missing.isEmpty else {
            let typeIDs = missing
                .sorted {
                    if $0.high == $1.high {
                        return $0.low < $1.low
                    }
                    return $0.high < $1.high
                }
                .map { "\($0.high):\($0.low)" }
                .joined(separator: ", ")
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation(
                    "Actor bootstrap \(bootstrapIdentifier) is missing codecs for method value type IDs: \(typeIDs)"
                )
            )
        }
    }

    public func register<Value: Codable & Sendable>(
        _ type: Value.Type,
        typeID: ActorTypeID,
        codec: ActorGeneratedCodec<Value>
    ) throws {
        let key = ObjectIdentifier(type)
        let erased = AnyCodec(
            swiftTypeID: key,
            typeID: typeID,
            encode: { value in
                guard let typed = value as? Value else {
                    throw ActorSystemError.encodingFailed
                }
                return try codec.encode(typed)
            },
            decode: { payload, options in
                try codec.decode(payload, options: options)
            }
        )
        try state.withLock { state in
            if let existing = state.codecsBySwiftType[key] {
                guard existing.typeID == typeID,
                      state.codecsByTypeID[typeID]?.swiftTypeID == key
                else {
                    throw ActorSystemError.encodingFailed
                }
                return
            }
            if let existing = state.codecsByTypeID[typeID],
               existing.swiftTypeID != key {
                throw ActorSystemError.encodingFailed
            }
            state.codecsBySwiftType[key] = erased
            state.codecsByTypeID[typeID] = erased
        }
    }

    public func encode<Value: Codable & Sendable>(_ value: Value) throws -> ActorByteBuffer {
        let prepared = try prepareEncoding(swiftTypeID: ObjectIdentifier(Value.self))
        return try prepared.encode(value)
    }

    public func decode<Value: Codable & Sendable>(
        _ type: Value.Type,
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) throws -> Value {
        let codec = state.withLock { state in
            state.codecsBySwiftType[ObjectIdentifier(type)]
        }
        guard let codec,
              let value = try codec.decode(payload, options) as? Value else {
            throw ActorSystemError.decodingFailed
        }
        return value
    }

    public func encodeDynamic(
        _ value: any Sendable,
        swiftType: Any.Type
    ) throws -> (typeID: ActorTypeID, payload: ActorByteBuffer) {
        let prepared = try prepareEncoding(swiftTypeID: ObjectIdentifier(swiftType))
        return (prepared.typeID, try prepared.encode(value))
    }

    func encodeDynamicIfRegistered(
        _ value: any Sendable,
        swiftType: Any.Type
    ) throws -> (typeID: ActorTypeID, payload: ActorByteBuffer)? {
        let codec = state.withLock { state in
            state.codecsBySwiftType[ObjectIdentifier(swiftType)]
        }
        guard let codec else {
            return nil
        }
        let prepared = PreparedEncoding(codec: codec)
        return (prepared.typeID, try prepared.encode(value))
    }

    func prepareEncoding(swiftTypeID: ObjectIdentifier) throws -> PreparedEncoding {
        let codec = state.withLock { state in
            state.codecsBySwiftType[swiftTypeID]
        }
        guard let codec else {
            throw ActorSystemError.encodingFailed
        }
        return PreparedEncoding(codec: codec)
    }

    public func decodeError(
        _ failure: ActorApplicationFailure,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) throws -> any Error {
        let codec = state.withLock { state in
            state.codecsByTypeID[failure.typeID]
        }
        guard let codec,
              let error = try codec.decode(failure.payload, options) as? any Error
        else {
            throw ActorSystemError.decodingFailed
        }
        return error
    }

    public func decodeError<Failure: Error>(
        _ type: Failure.Type,
        from failure: ActorApplicationFailure,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) throws -> Failure {
        guard let typed = try decodeError(failure, options: options) as? Failure else {
            throw ActorSystemError.decodingFailed
        }
        return typed
    }
}

public struct ActorBinaryEncoder: Sendable {
    private let prepareEncoding: @Sendable (
        ObjectIdentifier
    ) throws -> ActorDistributedCodecRegistry.PreparedEncoding

    public init(registry: ActorDistributedCodecRegistry) {
        self.prepareEncoding = { swiftTypeID in
            try registry.prepareEncoding(swiftTypeID: swiftTypeID)
        }
    }

    init(
        prepareEncoding: @escaping @Sendable (
            ObjectIdentifier
        ) throws -> ActorDistributedCodecRegistry.PreparedEncoding
    ) {
        self.prepareEncoding = prepareEncoding
    }

    public func encode<Value: Codable & Sendable>(_ value: Value) throws -> ActorByteBuffer {
        let prepared = try prepareEncoding(ObjectIdentifier(Value.self))
        return try prepared.encode(value)
    }
}

public struct ActorBinaryDecoder: Sendable {
    private let registry: ActorDistributedCodecRegistry
    private let options: ActorPortableDecodingOptions

    public init(
        registry: ActorDistributedCodecRegistry,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) {
        self.registry = registry
        self.options = options
    }

    public func decode<Value: Codable & Sendable>(
        _ type: Value.Type,
        from payload: ActorByteBuffer
    ) throws -> Value {
        try registry.decode(type, from: payload, options: options)
    }
}
