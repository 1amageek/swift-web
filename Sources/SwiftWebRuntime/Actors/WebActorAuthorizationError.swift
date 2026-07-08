public struct WebActorAuthorizationError: Error, Sendable, Equatable, CustomStringConvertible {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var description: String {
        reason
    }
}
