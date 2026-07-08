#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

public struct WebActorActivationPolicy: Sendable, Equatable {
    public let maximumVirtualActorCount: Int
    public let idleTimeout: TimeInterval?

    public init(
        maximumVirtualActorCount: Int = 1_024,
        idleTimeout: TimeInterval? = 30 * 60
    ) {
        self.maximumVirtualActorCount = maximumVirtualActorCount
        self.idleTimeout = idleTimeout
    }

    public static let defaults = WebActorActivationPolicy()

    public static let unbounded = WebActorActivationPolicy(
        maximumVirtualActorCount: Int.max,
        idleTimeout: nil
    )
}
