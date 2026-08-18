final class ActorOwnedTaskOwner: Sendable {}

enum ActorOwnedTaskKind: Sendable {
    case start
    case consumer
    case remoteTimeout
    case invocation
    case inbound
    case outbound
    case endpointCallback
}

struct ActorOwnedTaskIdentity: Sendable {
    let owner: ActorOwnedTaskOwner
    let kind: ActorOwnedTaskKind
    let ancestorOwners: [ActorOwnedTaskOwner]

    init(owner: ActorOwnedTaskOwner, kind: ActorOwnedTaskKind) {
        self.owner = owner
        self.kind = kind
        if let parent = ActorOwnedTaskContext.current {
            self.ancestorOwners = [parent.owner] + parent.ancestorOwners
        } else {
            self.ancestorOwners = []
        }
    }

    func contains(owner candidate: ActorOwnedTaskOwner) -> Bool {
        owner === candidate || ancestorOwners.contains { $0 === candidate }
    }
}

enum ActorOwnedTaskContext {
    @TaskLocal static var current: ActorOwnedTaskIdentity?
}
