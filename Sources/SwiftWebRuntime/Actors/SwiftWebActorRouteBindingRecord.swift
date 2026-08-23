import ActorSystemCore

/// Deployment-provided routing for one logical actor address.
///
/// The actor address remains location-free. Transport and endpoint data live
/// in this separate record so an environment can change placement without
/// changing application-authored actor references.
public struct SwiftWebActorRouteBindingRecord: Sendable, Equatable {
    public let actorID: ActorAddress
    public let route: ActorRoute

    public init(actorID: ActorAddress, route: ActorRoute) {
        self.actorID = actorID
        self.route = route
    }
}

#if !hasFeature(Embedded)
extension SwiftWebActorRouteBindingRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case actorTypeHigh
        case actorTypeLow
        case actorIdentity
        case transport
        case endpoint
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            actorID: ActorAddress(
                type: ActorTypeID(
                    high: try container.decode(UInt64.self, forKey: .actorTypeHigh),
                    low: try container.decode(UInt64.self, forKey: .actorTypeLow)
                ),
                identity: try container.decode(String.self, forKey: .actorIdentity)
            ),
            route: ActorRoute(
                transport: ActorTransportID(
                    try container.decode(String.self, forKey: .transport)
                ),
                endpoint: ActorEndpoint(
                    try container.decode(String.self, forKey: .endpoint)
                )
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actorID.type.high, forKey: .actorTypeHigh)
        try container.encode(actorID.type.low, forKey: .actorTypeLow)
        try container.encode(actorID.identity, forKey: .actorIdentity)
        try container.encode(route.transport.rawValue, forKey: .transport)
        try container.encode(route.endpoint.transportSpecificAddress, forKey: .endpoint)
    }
}
#endif
