import ActorSystemCore
#if SWIFTWEB_ACTORS
import Distributed
#endif

public struct SwiftWebActorFactory: Sendable {
    public let descriptor: ActorTypeDescriptor
#if SWIFTWEB_ACTORS
    private let activateValue: @Sendable (ActorAddress) async throws -> SwiftWebActivatedActor
#else
    private let activateValue: @Sendable (ActorAddress) async throws -> Void
#endif
    private let passivateValue: @Sendable (ActorAddress) -> Void

    public init<ActorType: ActorSystemReference>(
        _ actorType: ActorType.Type,
        activate: @escaping @Sendable (ActorAddress) async throws -> ActorType,
        passivate: @escaping @Sendable (ActorAddress) -> Void
    ) {
        self.descriptor = actorType.actorTypeDescriptor
#if SWIFTWEB_ACTORS
        self.activateValue = { address in
            let storageCollector = ActorStorageActivationContext.Collector()
            let remoteStateCollector = RemoteStateActivationContext.Collector()
            let actor = try await SwiftWebActorActivationIdentity.withValue(address) {
                try await ActorStorageActivationContext.withValue(storageCollector) {
                    try await RemoteStateActivationContext.withValue(remoteStateCollector) {
                        try await activate(address)
                    }
                }
            }
            guard actor.id == address else {
                passivate(actor.id)
                throw ActorSystemError.activationFailed
            }
            return SwiftWebActivatedActor(
                address: address,
                actor: actor,
                storageBoxes: storageCollector.collected(),
                remoteStateBindings: remoteStateCollector.collected()
            )
        }
#else
        self.activateValue = { address in
            let actor = try await activate(address)
            guard actor.id == address else {
                passivate(actor.id)
                throw ActorSystemError.activationFailed
            }
        }
#endif
        self.passivateValue = passivate
    }

#if SWIFTWEB_ACTORS
    func activate(address: ActorAddress) async throws -> SwiftWebActivatedActor {
        guard address.type == descriptor.id else {
            throw ActorSystemError.activationFailed
        }
        return try await activateValue(address)
    }
#else
    public func activate(address: ActorAddress) async throws {
        guard address.type == descriptor.id else {
            throw ActorSystemError.activationFailed
        }
        try await SwiftWebActorActivationIdentity.withValue(address) {
            try await activateValue(address)
        }
    }
#endif

    public func passivate(address: ActorAddress) {
        passivateValue(address)
    }
}

#if SWIFTWEB_ACTORS
struct SwiftWebActivatedActor: Sendable {
    let address: ActorAddress
    let storageBoxes: [any PersistentValueBox]
    let remoteStateBindings: [any RemoteStateBinding]
    private let activatedValue: @Sendable () async -> Void
    private let passivatingValue: @Sendable () async -> Void
    private let reminderValue: @Sendable (String) async throws -> Bool

    init<ActorType: ActorSystemReference>(
        address: ActorAddress,
        actor: ActorType,
        storageBoxes: [any PersistentValueBox],
        remoteStateBindings: [any RemoteStateBinding]
    ) {
        self.address = address
        self.storageBoxes = storageBoxes
        self.remoteStateBindings = remoteStateBindings
        self.activatedValue = {
            guard let lifecycle = actor as? any WebActorLifecycle else {
                return
            }
            await runActivatedHook(lifecycle)
        }
        self.passivatingValue = {
            guard let lifecycle = actor as? any WebActorLifecycle else {
                return
            }
            await runPassivatingHook(lifecycle)
        }
        self.reminderValue = { name in
            guard let remindable = actor as? any WebActorRemindable else {
                return false
            }
            try await runReminderHook(remindable, name: name)
            return true
        }
    }

    func activated() async {
        await activatedValue()
    }

    func passivating() async {
        await passivatingValue()
    }

    func deliverReminder(_ name: String) async throws -> Bool {
        try await reminderValue(name)
    }
}

private func runActivatedHook<Lifecycle: WebActorLifecycle>(
    _ lifecycle: Lifecycle
) async {
    await lifecycle.whenLocal { isolated in
        await isolated.activated()
    }
}

private func runPassivatingHook<Lifecycle: WebActorLifecycle>(
    _ lifecycle: Lifecycle
) async {
    await lifecycle.whenLocal { isolated in
        await isolated.passivating()
    }
}

private func runReminderHook<Remindable: WebActorRemindable>(
    _ remindable: Remindable,
    name: String
) async throws {
    try await remindable.whenLocal { isolated in
        try await isolated.reminder(name)
    }
}
#endif
