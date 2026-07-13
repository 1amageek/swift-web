#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime

public struct WebActorAuthorizationRequest: Sendable {
    public let envelope: InvocationEnvelope
    public let recipient: WebActorRecipient
    public let targetIdentifier: String
    public let context: WebActorInvocationContext
    public let isRegistered: Bool
    public let isVirtualActor: Bool

    public init(
        envelope: InvocationEnvelope,
        recipient: WebActorRecipient,
        targetIdentifier: String,
        context: WebActorInvocationContext,
        isRegistered: Bool,
        isVirtualActor: Bool
    ) {
        self.envelope = envelope
        self.recipient = recipient
        self.targetIdentifier = targetIdentifier
        self.context = context
        self.isRegistered = isRegistered
        self.isVirtualActor = isVirtualActor
    }
}
#endif
