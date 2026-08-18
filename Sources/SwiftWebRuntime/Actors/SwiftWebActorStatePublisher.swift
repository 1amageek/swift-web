#if SWIFTWEB_ACTORS
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// A state change published by a concrete actor hosted by `WebActorSystem`.
public struct SwiftWebRemoteStateChange: Sendable, Equatable {
    public let actorAddress: ActorAddress
    public let key: String
    public let value: Data

    public init(actorAddress: ActorAddress, key: String, value: Data) {
        self.actorAddress = actorAddress
        self.key = key
        self.value = value
    }
}

/// Receives state changes from concrete actors on the binary actor path.
public protocol SwiftWebActorStatePublisher: Sendable {
    func publish(_ change: SwiftWebRemoteStateChange) async
    func finish(actorAddress: ActorAddress) async
}

public extension SwiftWebActorStatePublisher {
    func finish(actorAddress: ActorAddress) async {}
}
#endif
