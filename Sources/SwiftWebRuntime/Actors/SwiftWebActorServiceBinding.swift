import ActorSystemCore

/// A deployment-owned route template for one actor identity.
///
/// Application code supplies the logical identity through `.actor(_:identity:)`.
/// The platform adapter supplies this template, which keeps transport and
/// endpoint placement outside the actor address and the application source.
public struct SwiftWebActorRouteTemplate: Sendable, Equatable {
    public let transport: ActorTransportID
    public let endpointPrefix: String
    public let endpointSuffix: String

    public init(
        transport: ActorTransportID,
        endpointPrefix: String,
        endpointSuffix: String = ""
    ) {
        self.transport = transport
        self.endpointPrefix = endpointPrefix
        self.endpointSuffix = endpointSuffix
    }

    public func route(identity: String) throws -> ActorRoute {
        guard !transport.rawValue.isEmpty else {
            throw SwiftWebActorServiceBindingError.emptyTransport
        }
        guard !identity.isEmpty else {
            throw SwiftWebActorServiceBindingError.emptyIdentity
        }
        let rendered = endpointPrefix
            + Self.endpointComponent(identity)
            + endpointSuffix
        return ActorRoute(
            transport: transport,
            endpoint: ActorEndpoint(rendered)
        )
    }

    private static func endpointComponent(_ value: String) -> String {
        var result = ""
        for byte in value.utf8 {
            switch byte {
            case 0x41...0x5A, 0x61...0x7A, 0x30...0x39,
                 0x2D, 0x2E, 0x5F, 0x7E:
                result.append(Character(UnicodeScalar(byte)))
            default:
                let digits = Array("0123456789ABCDEF".utf8)
                result.append("%")
                result.append(Character(UnicodeScalar(digits[Int(byte >> 4)])))
                result.append(Character(UnicodeScalar(digits[Int(byte & 0x0F)])))
            }
        }
        return result
    }
}

/// Adapter-provided placement for every identity of one concrete actor type.
///
/// `hostRoute` is used by server-side Swift. `clientRoute`, when present, is
/// serialized into browser bootstrap data so an internal platform endpoint is
/// never exposed to the browser.
public struct SwiftWebActorServiceBinding: Sendable, Equatable {
    public let actorType: ActorTypeID
    public let hostRoute: SwiftWebActorRouteTemplate
    public let clientRoute: SwiftWebActorRouteTemplate?

    public init(
        actorType: ActorTypeID,
        hostRoute: SwiftWebActorRouteTemplate,
        clientRoute: SwiftWebActorRouteTemplate? = nil
    ) {
        self.actorType = actorType
        self.hostRoute = hostRoute
        self.clientRoute = clientRoute
    }
}

public enum SwiftWebActorServiceBindingError: Error, Sendable, Equatable {
    case duplicateActorType(ActorTypeID)
    case emptyTransport
    case emptyIdentity
}
