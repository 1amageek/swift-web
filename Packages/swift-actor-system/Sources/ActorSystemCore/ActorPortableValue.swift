public struct ActorPortableDecodingOptions: Hashable, Sendable {
    public let maximumCollectionElements: Int
    public let maximumNestingDepth: Int
    public let currentNestingDepth: Int

    public init(
        maximumCollectionElements: Int = 100_000,
        maximumNestingDepth: Int = 64
    ) {
        self.maximumCollectionElements = maximumCollectionElements
        self.maximumNestingDepth = maximumNestingDepth
        self.currentNestingDepth = 0
    }

    init(
        maximumCollectionElements: Int,
        maximumNestingDepth: Int,
        currentNestingDepth: Int
    ) {
        self.maximumCollectionElements = maximumCollectionElements
        self.maximumNestingDepth = maximumNestingDepth
        self.currentNestingDepth = currentNestingDepth
    }

    public func descending() throws -> ActorPortableDecodingOptions {
        let nextDepth = currentNestingDepth + 1
        guard nextDepth < maximumNestingDepth else {
            throw ActorSystemError.decodingFailed
        }
        return ActorPortableDecodingOptions(
            maximumCollectionElements: maximumCollectionElements,
            maximumNestingDepth: maximumNestingDepth,
            currentNestingDepth: nextDepth
        )
    }
}

public protocol ActorPortableValue: Sendable {
    func encodeActorValue() throws -> ActorByteBuffer

    static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> Self
}

public extension ActorGeneratedCodec where Value: ActorPortableValue {
    static func portable(
        _ type: Value.Type = Value.self,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) -> ActorGeneratedCodec<Value> {
        ActorGeneratedCodec<Value>(
            encode: { value in
                try value.encodeActorValue()
            },
            decodeWithOptions: { payload, runtimeOptions in
                let effectiveOptions = ActorPortableDecodingOptions(
                    maximumCollectionElements: Swift.min(
                        options.maximumCollectionElements,
                        runtimeOptions.maximumCollectionElements
                    ),
                    maximumNestingDepth: Swift.min(
                        options.maximumNestingDepth,
                        runtimeOptions.maximumNestingDepth
                    ),
                    currentNestingDepth: runtimeOptions.currentNestingDepth
                )
                return try Value.decodeActorValue(
                    from: payload,
                    options: effectiveOptions
                )
            }
        )
    }
}

extension Bool: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(self, field: ActorFieldID(1))
        return encoder.finish()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> Bool {
        try decodeSingleField(payload, options: options) { try $0.decodeBool() }
    }
}

extension Int: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        try encodeSignedInteger(self)
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> Int {
        try decodeSingleField(payload, options: options) {
            try $0.decodeSignedInteger(as: Int.self)
        }
    }
}

extension Int8: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeSignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Int8 {
        try decodeSingleField(payload, options: options) { try $0.decodeSignedInteger(as: Int8.self) }
    }
}

extension Int16: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeSignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Int16 {
        try decodeSingleField(payload, options: options) { try $0.decodeSignedInteger(as: Int16.self) }
    }
}

extension Int32: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeSignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Int32 {
        try decodeSingleField(payload, options: options) { try $0.decodeSignedInteger(as: Int32.self) }
    }
}

extension Int64: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeSignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Int64 {
        try decodeSingleField(payload, options: options) { try $0.decodeSignedInteger(as: Int64.self) }
    }
}

extension UInt: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeUnsignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> UInt {
        try decodeSingleField(payload, options: options) { try $0.decodeUnsignedInteger(as: UInt.self) }
    }
}

extension UInt8: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeUnsignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> UInt8 {
        try decodeSingleField(payload, options: options) { try $0.decodeUnsignedInteger(as: UInt8.self) }
    }
}

extension UInt16: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeUnsignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> UInt16 {
        try decodeSingleField(payload, options: options) { try $0.decodeUnsignedInteger(as: UInt16.self) }
    }
}

extension UInt32: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeUnsignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> UInt32 {
        try decodeSingleField(payload, options: options) { try $0.decodeUnsignedInteger(as: UInt32.self) }
    }
}

extension UInt64: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer { try encodeUnsignedInteger(self) }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> UInt64 {
        try decodeSingleField(payload, options: options) { try $0.decodeUnsignedInteger(as: UInt64.self) }
    }
}

extension Float: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(self, field: ActorFieldID(1))
        return encoder.finish()
    }

    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Float {
        try decodeSingleField(payload, options: options) { try $0.decodeFloat() }
    }
}

extension Double: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(self, field: ActorFieldID(1))
        return encoder.finish()
    }

    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Double {
        try decodeSingleField(payload, options: options) { try $0.decodeDouble() }
    }
}

extension String: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(self, field: ActorFieldID(1))
        return encoder.finish()
    }

    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> String {
        try decodeSingleField(payload, options: options) { try $0.decodeString() }
    }
}

extension ActorByteBuffer: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(bytes: self, field: ActorFieldID(1))
        return encoder.finish()
    }

    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> ActorByteBuffer {
        try decodeSingleField(payload, options: options) { try $0.decodeBytes() }
    }
}

extension Optional: ActorPortableValue where Wrapped: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        switch self {
        case .none:
            try encoder.appendNull(field: ActorFieldID(1))
        case .some(let value):
            try encoder.append(
                message: value.encodeActorValue(),
                field: ActorFieldID(1)
            )
        }
        return encoder.finish()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> Wrapped? {
        try decodeSingleField(payload, options: options) { field in
            if field.isNull {
                return nil
            }
            guard field.wireType == .message else {
                throw ActorSystemError.decodingFailed
            }
            return try Wrapped.decodeActorValue(
                from: field.payloadBuffer(),
                options: options.descending()
            )
        }
    }
}

extension Array: ActorPortableValue where Element: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        for (index, value) in enumerated() {
            guard let fieldID = UInt32(exactly: index + 1) else {
                throw ActorSystemError.encodingFailed
            }
            try encoder.append(
                message: value.encodeActorValue(),
                field: ActorFieldID(fieldID)
            )
        }
        return encoder.finish()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> [Element] {
        var decoder = try ActorPayloadDecoder(
            payload,
            options: options
        )
        var values: [Element] = []
        while let field = try decoder.nextField() {
            guard let expectedID = UInt32(exactly: values.count + 1),
                  field.id.rawValue == expectedID,
                  field.wireType == .message
            else {
                throw ActorSystemError.decodingFailed
            }
            values.append(
                try Element.decodeActorValue(
                    from: field.payloadBuffer(),
                    options: options.descending()
                )
            )
        }
        return values
    }
}

extension Dictionary: ActorPortableValue
where Key: ActorPortableValue & Hashable, Value: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var encodedEntries: [(key: [UInt8], entry: ActorByteBuffer)] = []
        encodedEntries.reserveCapacity(count)
        for (key, value) in self {
            let keyPayload = try key.encodeActorValue()
            var entryEncoder = ActorPayloadEncoder()
            try entryEncoder.append(message: keyPayload, field: ActorFieldID(1))
            try entryEncoder.append(
                message: value.encodeActorValue(),
                field: ActorFieldID(2)
            )
            // Canonical map ordering needs an owned key snapshot while the
            // final payload is assembled; this is the one intentional key copy.
            encodedEntries.append((keyPayload.bytes, entryEncoder.finish()))
        }
        encodedEntries.sort { actorLexicographicallyPrecedes($0.key, $1.key) }
        if encodedEntries.count > 1 {
            for index in 1..<encodedEntries.count
            where encodedEntries[index - 1].key == encodedEntries[index].key {
                throw ActorSystemError.encodingFailed
            }
        }

        var encoder = ActorPayloadEncoder()
        for (index, encoded) in encodedEntries.enumerated() {
            guard let fieldID = UInt32(exactly: index + 1) else {
                throw ActorSystemError.encodingFailed
            }
            try encoder.append(
                message: encoded.entry,
                field: ActorFieldID(fieldID)
            )
        }
        return encoder.finish()
    }

    public static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> [Key: Value] {
        var decoder = try ActorPayloadDecoder(
            payload,
            options: options
        )
        var result: [Key: Value] = [:]
        var entryIndex = 0
        while let field = try decoder.nextField() {
            entryIndex += 1
            guard field.id.rawValue == UInt32(entryIndex), field.wireType == .message else {
                throw ActorSystemError.decodingFailed
            }
            var entryDecoder = try field.nestedDecoder(accepting: [.message])
            let entryOptions = try options.descending()
            guard let keyField = try entryDecoder.nextField(),
                  keyField.id == ActorFieldID(1),
                  keyField.wireType == .message,
                  let valueField = try entryDecoder.nextField(),
                  valueField.id == ActorFieldID(2),
                  valueField.wireType == .message
            else {
                throw ActorSystemError.decodingFailed
            }
            if let _ = try entryDecoder.nextField() {
                throw ActorSystemError.decodingFailed
            }
            let key = try Key.decodeActorValue(
                from: keyField.payloadBuffer(),
                options: entryOptions.descending()
            )
            guard result[key] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("A portable map contains a duplicate key")
                )
            }
            result[key] = try Value.decodeActorValue(
                from: valueField.payloadBuffer(),
                options: entryOptions.descending()
            )
        }
        return result
    }
}

private func encodeSignedInteger<T: FixedWidthInteger & SignedInteger>(
    _ value: T
) throws -> ActorByteBuffer {
    var encoder = ActorPayloadEncoder()
    try encoder.append(value, field: ActorFieldID(1))
    return encoder.finish()
}

private func encodeUnsignedInteger<T: FixedWidthInteger & UnsignedInteger>(
    _ value: T
) throws -> ActorByteBuffer {
    var encoder = ActorPayloadEncoder()
    try encoder.append(value, field: ActorFieldID(1))
    return encoder.finish()
}

private func decodeSingleField<Value>(
    _ payload: ActorByteBuffer,
    options: ActorPortableDecodingOptions,
    decode: (ActorFieldView) throws -> Value
) throws -> Value {
    var decoder = try ActorPayloadDecoder(
        payload,
        options: options
    )
    guard let field = try decoder.nextField(),
          field.id == ActorFieldID(1)
    else {
        throw ActorSystemError.decodingFailed
    }
    if let _ = try decoder.nextField() {
        throw ActorSystemError.decodingFailed
    }
    return try decode(field)
}

private func actorLexicographicallyPrecedes(_ left: [UInt8], _ right: [UInt8]) -> Bool {
    let commonCount = Swift.min(left.count, right.count)
    for index in 0..<commonCount {
        if left[index] != right[index] {
            return left[index] < right[index]
        }
    }
    return left.count < right.count
}
