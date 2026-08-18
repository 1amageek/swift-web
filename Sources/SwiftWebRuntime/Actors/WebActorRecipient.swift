#if SWIFTWEB_LEGACY_ACTORS
public struct WebActorRecipient: Sendable, Equatable, Hashable {
    public let actorID: LegacyWebActorSystem.ActorID
    public let contract: String?
    public let name: String?

    public init(actorID: LegacyWebActorSystem.ActorID) {
        self.actorID = actorID
        guard let separator = actorID.firstIndex(of: ":") else {
            self.contract = nil
            self.name = nil
            return
        }
        self.contract = String(actorID[..<separator])
        self.name = String(actorID[actorID.index(after: separator)...])
    }
}
#endif
