public protocol ActorIdentitySource: Sendable {
    func nextIdentity(for actorType: ActorTypeID) -> String
}
