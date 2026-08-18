public struct ActorMethodDescriptor: Hashable, Sendable {
    public let id: ActorMethodID
    public let parameterTypeIDs: [ActorTypeID]
    public let resultTypeID: ActorTypeID?
    public let errorTypeID: ActorTypeID?

    public init(
        id: ActorMethodID,
        parameterTypeIDs: [ActorTypeID],
        resultTypeID: ActorTypeID?,
        errorTypeID: ActorTypeID?
    ) {
        self.id = id
        self.parameterTypeIDs = parameterTypeIDs
        self.resultTypeID = resultTypeID
        self.errorTypeID = errorTypeID
    }
}

public struct ActorTypeDescriptor: Hashable, Sendable {
    public let id: ActorTypeID
    public let schemaFingerprint: ActorSchemaFingerprint
    public let methods: [ActorMethodDescriptor]

    public init(
        id: ActorTypeID,
        schemaFingerprint: ActorSchemaFingerprint,
        methods: [ActorMethodDescriptor]
    ) {
        self.id = id
        self.schemaFingerprint = schemaFingerprint
        self.methods = methods
    }

    public func method(id: ActorMethodID) -> ActorMethodDescriptor? {
        methods.first { $0.id == id }
    }

    public func validate() throws {
        var methodIDs = Set<ActorMethodID>()
        for method in methods {
            guard methodIDs.insert(method.id).inserted else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation(
                        "An actor descriptor contains a duplicate method ID"
                    )
                )
            }
        }
    }
}
