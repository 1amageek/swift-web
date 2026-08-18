public struct ActorTypeID: Hashable, Sendable {
    public let high: UInt64
    public let low: UInt64

    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
}

public struct ActorSchemaFingerprint: Hashable, Sendable {
    public let high: UInt64
    public let low: UInt64

    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
}

public struct ActorMethodID: Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public struct ActorSessionID: Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public struct ActorCallID: Hashable, Sendable {
    public let session: ActorSessionID
    public let sequence: UInt64

    public init(session: ActorSessionID, sequence: UInt64) {
        self.session = session
        self.sequence = sequence
    }
}

public struct ActorTransportID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ActorEndpoint: Hashable, Sendable {
    public let transportSpecificAddress: String

    public init(_ transportSpecificAddress: String) {
        self.transportSpecificAddress = transportSpecificAddress
    }
}

public struct ActorAddress: Hashable, Sendable {
    public let type: ActorTypeID
    public let identity: String

    public init(type: ActorTypeID, identity: String) {
        self.type = type
        self.identity = identity
    }

    public init(type: ActorTypeID, name: String) {
        self.init(type: type, identity: name)
    }
}
