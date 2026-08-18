#if SWIFTWEB_ACTORS
@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

private final class SwiftWebActorHostTaskOwner: Sendable {}

private enum SwiftWebActorHostTaskContext {
    @TaskLocal static var owner: SwiftWebActorHostTaskOwner?
}

public actor SwiftWebActorHost: ActorInboundInvocationInterceptor, ActorLocalInvocationClaiming {
    private enum Phase: Sendable, Equatable {
        case accepting
        case draining
        case finalizing
        case stopped
    }

    private struct FactoryRegistration: Sendable {
        let factory: SwiftWebActorFactory
        let authorization: SwiftWebActorAuthorization?
        let passivation: ActorPassivationPolicy?
    }

    private struct HostedActor: Sendable {
        let activation: SwiftWebActivatedActor?
        let gate: SwiftWebActorInvocationGate
        var lastAccess: Date
        var pendingInvocations: Int

        var isVirtual: Bool {
            activation != nil
        }
    }

    private let policy: any SwiftWebActorHostPolicy
    private let maximumConcurrentInvocations: Int
    private var authorization: SwiftWebActorAuthorization
    private var activationPolicy: WebActorActivationPolicy
    private var persistentStore: (any WebActorPersistentStore)?
    private var statePublisher: (any SwiftWebActorStatePublisher)?
    private nonisolated let reminderBackend: SwiftWebActorReminderBackend
    private let persistentState = ActorPersistentStateRegistry()
    private var factories: [ActorTypeID: FactoryRegistration] = [:]
    private var activeActors: [ActorAddress: HostedActor] = [:]
    private var passivatingActors: [ActorAddress: HostedActor] = [:]
    private var activationTasks: [ActorAddress: Task<SwiftWebActivatedActor, any Error>] = [:]
    private var activationReservations: Set<ActorAddress> = []
    private var passivationTasks: [ActorAddress: Task<Void, any Error>] = [:]
    private var idleTasks: [ActorAddress: Task<Void, Never>] = [:]
    private var unregisteringActorTypes: Set<ActorTypeID> = []
    private var phase = Phase.accepting
    private var configurationSealed = false
    private var inFlightInvocations = 0
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private var shutdownPreparation: ActorSystemTermination?
    private var shutdownFinalization: ActorSystemTermination?
    private let ownedTaskOwner = SwiftWebActorHostTaskOwner()

    public init(
        policy: any SwiftWebActorHostPolicy = DirectSwiftWebActorHostPolicy(),
        authorization: SwiftWebActorAuthorization = .trustedOnly,
        activationPolicy: WebActorActivationPolicy = .defaults,
        maximumConcurrentInvocations: Int = 1_024,
        persistentStore: (any WebActorPersistentStore)? = nil,
        statePublisher: (any SwiftWebActorStatePublisher)? = nil,
        reminderStore: (any SwiftWebActorReminderStore)? = nil
    ) {
        self.policy = policy
        self.maximumConcurrentInvocations = maximumConcurrentInvocations
        self.authorization = authorization
        self.activationPolicy = activationPolicy
        self.persistentStore = persistentStore
        self.statePublisher = statePublisher
        self.reminderBackend = SwiftWebActorReminderBackend(store: reminderStore)
    }

    public func installAuthorization(
        _ authorization: SwiftWebActorAuthorization
    ) throws {
        try requireMutableConfiguration()
        self.authorization = authorization
    }

    public func installPersistentStore(
        _ store: any WebActorPersistentStore
    ) throws {
        try requireMutableConfiguration()
        persistentStore = store
    }

    public func installActivationPolicy(
        _ policy: WebActorActivationPolicy
    ) throws {
        try requireMutableConfiguration()
        activationPolicy = policy
    }

    public func installStatePublisher(
        _ publisher: any SwiftWebActorStatePublisher
    ) throws {
        try requireMutableConfiguration()
        statePublisher = publisher
    }

    public func installReminderStore(
        _ store: any SwiftWebActorReminderStore
    ) async throws {
        try requireMutableConfiguration()
        let previous = reminderBackend.install(store)
        if let previous {
            await previous.shutdown()
        }
    }

    public nonisolated func reminders(
        for address: ActorAddress
    ) -> SwiftWebActorReminders {
        SwiftWebActorReminders(actorAddress: address, backend: reminderBackend)
    }

    public func sealConfiguration() throws {
        guard phase == .accepting, inFlightInvocations == 0 else {
            throw SwiftWebActorHostError.authorizationConfigurationLocked
        }
        guard maximumConcurrentInvocations > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor host invocation limit is invalid")
            )
        }
        configurationSealed = true
    }

    public func register(
        _ factory: SwiftWebActorFactory,
        authorization: SwiftWebActorAuthorization? = nil,
        passivation: ActorPassivationPolicy? = nil
    ) throws {
        guard phase == .accepting, !configurationSealed else {
            throw SwiftWebActorHostError.configurationLocked
        }
        let actorType = factory.descriptor.id
        guard factories[actorType] == nil else {
            throw SwiftWebActorHostError.duplicateFactory(actorType)
        }
        try factory.descriptor.validate()
        factories[actorType] = FactoryRegistration(
            factory: factory,
            authorization: authorization,
            passivation: passivation
        )
    }

    public func registerBound(address: ActorAddress) throws {
        guard phase == .accepting, !configurationSealed else {
            throw SwiftWebActorHostError.configurationLocked
        }
        if let existing = activeActors[address] {
            guard existing.activation == nil else {
                throw SwiftWebActorHostError.duplicateActiveActor(address)
            }
            return
        }
        activeActors[address] = HostedActor(
            activation: nil,
            gate: SwiftWebActorInvocationGate(),
            lastAccess: Date(),
            pendingInvocations: 0
        )
    }

    public func unregister(actorType: ActorTypeID) async throws {
        guard phase == .accepting else {
            throw SwiftWebActorHostError.hostShuttingDown
        }
        guard let registration = factories[actorType] else {
            return
        }
        guard unregisteringActorTypes.insert(actorType).inserted else {
            throw ActorSystemError.overloaded
        }
        defer { unregisteringActorTypes.remove(actorType) }

        let pendingActivations = activationTasks.filter { $0.key.type == actorType }
        for task in pendingActivations.values {
            task.cancel()
        }
        for (address, task) in pendingActivations {
            let activation: SwiftWebActivatedActor
            do {
                activation = try await task.value
            } catch {
                activationTasks[address] = nil
                activationReservations.remove(address)
                continue
            }
            activationTasks[address] = nil
            activationReservations.remove(address)
            try await forcePassivate(
                address: address,
                hosted: HostedActor(
                    activation: activation,
                    gate: SwiftWebActorInvocationGate(),
                    lastAccess: Date(),
                    pendingInvocations: 0
                ),
                registration: registration
            )
        }
        let pendingPassivations = passivationTasks.filter { $0.key.type == actorType }
        for (address, task) in pendingPassivations {
            do {
                try await task.value
                passivatingActors[address] = nil
            } catch {
                let hosted = passivatingActors.removeValue(forKey: address)
                passivationTasks[address] = nil
                if let hosted {
                    try await forcePassivate(
                        address: address,
                        hosted: hosted,
                        registration: registration
                    )
                }
                continue
            }
            passivationTasks[address] = nil
        }
        let addresses = activeActors
            .filter { $0.key.type == actorType && $0.value.isVirtual }
            .map(\.key)
        for address in addresses {
            try await passivate(address: address)
        }
        factories[actorType] = nil
    }

    public func claimsLocalInvocation(for recipient: ActorAddress) async -> Bool {
        factories[recipient.type] != nil || activeActors[recipient] != nil
    }

    public func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        guard phase == .accepting else {
            throw SwiftWebActorHostError.hostShuttingDown
        }
        guard !unregisteringActorTypes.contains(invocation.recipient.type) else {
            throw ActorSystemError.activationFailed
        }
        guard inFlightInvocations < maximumConcurrentInvocations else {
            throw ActorSystemError.overloaded
        }
        inFlightInvocations += 1
        return try await SwiftWebActorHostTaskContext.$owner.withValue(
            ownedTaskOwner
        ) {
            do {
                let swiftWebContext = try SwiftWebActorInvocationContextCodec(
                    maximumEncodedBytes: context.metadata.count,
                    maximumFieldBytes: min(1_024, context.metadata.count)
                ).decode(context.metadata)
                let authorizationRequest = SwiftWebActorAuthorizationRequest(
                    invocation: invocation,
                    context: swiftWebContext,
                    origin: context.origin,
                    isActive: activeActors[invocation.recipient] != nil
                )
                try await authorization.authorize(authorizationRequest)
                try await policy.authorize(
                    invocation,
                    context: context,
                    isActive: authorizationRequest.isActive
                )
                if let scopedAuthorization = factories[invocation.recipient.type]?.authorization {
                    try await scopedAuthorization.authorize(authorizationRequest)
                }
                if activeActors[invocation.recipient] == nil {
                    try await activate(address: invocation.recipient)
                }
                let result = try await execute(
                    invocation,
                    context: context,
                    execution: execution
                )
                finishInvocation()
                return result
            } catch {
                finishInvocation()
                throw error
            }
        }
    }

    public func passivate(address: ActorAddress) async throws {
        guard phase == .accepting else {
            throw SwiftWebActorHostError.hostShuttingDown
        }
        if let task = passivationTasks[address] {
            try await task.value
            return
        }
        guard let hosted = activeActors[address] else {
            return
        }
        guard hosted.isVirtual else {
            throw SwiftWebActorHostError.actorIsBound(address)
        }
        guard hosted.pendingInvocations == 0 else {
            throw SwiftWebActorHostError.actorBusy(address)
        }
        try await startPassivation(address: address, hosted: hosted)
    }

    public func deliverReminder(
        _ reminder: SwiftWebActorReminder
    ) async throws {
        guard phase == .accepting else {
            throw SwiftWebActorHostError.hostShuttingDown
        }
        guard inFlightInvocations < maximumConcurrentInvocations else {
            throw ActorSystemError.overloaded
        }
        inFlightInvocations += 1
        try await SwiftWebActorHostTaskContext.$owner.withValue(ownedTaskOwner) {
            do {
                if activeActors[reminder.actorAddress] == nil {
                    try await activate(address: reminder.actorAddress)
                }
                guard var hosted = activeActors[reminder.actorAddress],
                      let activation = hosted.activation
                else {
                    throw SwiftWebActorReminderError.actorNotRemindable(
                        actorAddress: reminder.actorAddress,
                        name: reminder.name
                    )
                }
                cancelIdleTask(for: reminder.actorAddress)
                hosted.pendingInvocations += 1
                activeActors[reminder.actorAddress] = hosted
                do {
                    try await hosted.gate.acquire()
                } catch {
                    releaseInvocationReservation(for: reminder.actorAddress)
                    throw error
                }
                do {
                    let wasDelivered = try await activation.deliverReminder(reminder.name)
                    guard wasDelivered else {
                        throw SwiftWebActorReminderError.actorNotRemindable(
                            actorAddress: reminder.actorAddress,
                            name: reminder.name
                        )
                    }
                    try await persistentState.save(
                        id: Self.persistenceKey(for: reminder.actorAddress),
                        store: persistentStore
                    )
                    await hosted.gate.release()
                    releaseInvocationReservation(for: reminder.actorAddress)
                    finishInvocation()
                } catch {
                    await hosted.gate.release()
                    releaseInvocationReservation(for: reminder.actorAddress)
                    throw error
                }
            } catch {
                finishInvocation()
                throw error
            }
        }
    }

    public func requestStopAdmission() -> ActorSystemTermination {
        if let shutdownPreparation {
            return shutdownPreparation
        }
        switch phase {
        case .stopped:
            return .alreadyTerminated()
        case .draining, .finalizing:
            return shutdownPreparation ?? .alreadyTerminated()
        case .accepting:
            phase = .draining
        }
        cancelAllIdleTasks()
        for task in activationTasks.values {
            task.cancel()
        }
        let reminderStore = reminderBackend.removeStore()
        let taskOwner = ownedTaskOwner
        let termination = ActorSystemTermination(
            waitIsReentrant: {
                SwiftWebActorHostTaskContext.owner === taskOwner
            },
            operation: {
                await SwiftWebActorHostTaskContext.$owner.withValue(taskOwner) {
                    if let reminderStore {
                        await reminderStore.shutdown()
                    }
                }
            }
        )
        shutdownPreparation = termination
        return termination
    }

    public func requestFinishShutdown() -> ActorSystemTermination {
        let preparation = requestStopAdmission()
        if let shutdownFinalization {
            return shutdownFinalization
        }
        guard phase != .stopped else {
            return .alreadyTerminated()
        }
        phase = .finalizing
        let taskOwner = ownedTaskOwner
        let termination = ActorSystemTermination(
            dependencies: { [preparation] },
            operation: {
                try await SwiftWebActorHostTaskContext.$owner.withValue(taskOwner) {
                    try await self.finalizeShutdown()
                }
            }
        )
        shutdownFinalization = termination
        return termination
    }

    public func requestShutdown() -> ActorSystemTermination {
        requestFinishShutdown()
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    private func finalizeShutdown() async throws {
        if inFlightInvocations > 0 {
            await withCheckedContinuation { continuation in
                drainWaiters.append(continuation)
            }
        }

        let pendingPassivations = passivationTasks
        var failedPassivations: [ActorAddress: HostedActor] = [:]
        for (address, task) in pendingPassivations {
            do {
                try await task.value
                passivatingActors[address] = nil
            } catch {
                failedPassivations[address] = passivatingActors[address]
                passivatingActors[address] = nil
            }
            passivationTasks[address] = nil
        }

        let pendingActivations = activationTasks
        var completedActivations: [ActorAddress: HostedActor] = [:]
        for (address, task) in pendingActivations {
            do {
                let activation = try await task.value
                completedActivations[address] = HostedActor(
                    activation: activation,
                    gate: SwiftWebActorInvocationGate(),
                    lastAccess: Date(),
                    pendingInvocations: 0
                )
            } catch {
                // Activation rollback is owned by the activation task.
            }
            activationTasks[address] = nil
            activationReservations.remove(address)
        }

        let registrations = factories
        factories.removeAll(keepingCapacity: false)
        var actors = activeActors
        for (address, hosted) in failedPassivations {
            actors[address] = hosted
        }
        for (address, hosted) in completedActivations {
            actors[address] = hosted
        }
        activeActors.removeAll(keepingCapacity: false)
        passivatingActors.removeAll(keepingCapacity: false)

        var firstFailure: (any Error)?
        for (address, hosted) in actors where hosted.isVirtual {
            guard let registration = registrations[address.type] else {
                continue
            }
            do {
                try await forcePassivate(
                    address: address,
                    hosted: hosted,
                    registration: registration
                )
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
            }
        }
        await policy.shutdown()
        phase = .stopped
        if let firstFailure {
            throw firstFailure
        }
    }

    private func requireMutableConfiguration() throws {
        guard phase == .accepting,
              !configurationSealed,
              inFlightInvocations == 0
        else {
            throw SwiftWebActorHostError.authorizationConfigurationLocked
        }
    }

    private func execute(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        guard var hosted = activeActors[invocation.recipient] else {
            throw ActorSystemError.actorNotFound(invocation.recipient)
        }
        cancelIdleTask(for: invocation.recipient)
        hosted.pendingInvocations += 1
        activeActors[invocation.recipient] = hosted
        do {
            try await hosted.gate.acquire()
        } catch {
            releaseInvocationReservation(for: invocation.recipient)
            throw error
        }
        do {
            try await policy.willInvoke(invocation, context: context)
            let result = try await execution()
            if hosted.isVirtual {
                try await persistentState.save(
                    id: Self.persistenceKey(for: invocation.recipient),
                    store: persistentStore
                )
            }
            try await policy.didInvoke(
                invocation,
                result: result,
                context: context
            )
            await hosted.gate.release()
            releaseInvocationReservation(for: invocation.recipient)
            return result
        } catch {
            await policy.invocationFailed(
                invocation,
                error: error,
                context: context
            )
            await hosted.gate.release()
            releaseInvocationReservation(for: invocation.recipient)
            throw error
        }
    }

    private func activate(address: ActorAddress) async throws {
        if let passivationTask = passivationTasks[address] {
            do {
                try await passivationTask.value
                passivationTasks[address] = nil
                passivatingActors[address] = nil
            } catch {
                passivationTasks[address] = nil
                if let restored = passivatingActors.removeValue(forKey: address),
                   phase == .accepting {
                    activeActors[address] = restored
                    scheduleIdlePassivation(for: address)
                }
                throw error
            }
        }
        if activeActors[address] != nil {
            return
        }
        if let task = activationTasks[address] {
            let activation: SwiftWebActivatedActor
            do {
                activation = try await task.value
            } catch {
                activationTasks[address] = nil
                activationReservations.remove(address)
                throw error
            }
            guard canInstallActivation(at: address) else {
                throw ActorSystemError.activationFailed
            }
            activationTasks[address] = nil
            activationReservations.remove(address)
            installActivationIfNeeded(activation, at: address)
            return
        }
        guard let registration = factories[address.type] else {
            await policy.activationFailed(
                address: address,
                error: SwiftWebActorHostError.factoryNotFound(address.type)
            )
            throw ActorSystemError.activationFailed
        }

        let policy = self.policy
        let persistentState = self.persistentState
        let persistentStore = self.persistentStore
        let statePublisher = self.statePublisher
        let persistenceKey = Self.persistenceKey(for: address)
        let task = makeOwnedThrowingTask {
            do {
                try await self.reserveActivationCapacity(for: address)
                try await policy.willActivate(address: address)
                let activation: SwiftWebActivatedActor
                do {
                    activation = try await registration.factory.activate(address: address)
                } catch {
                    await policy.activationFailed(address: address, error: error)
                    throw ActorSystemError.activationFailed
                }
                do {
                    try persistentState.bind(
                        id: persistenceKey,
                        boxes: activation.storageBoxes
                    )
                    if let statePublisher {
                        for binding in activation.remoteStateBindings {
                            binding.bind(
                                actorAddress: address,
                                publisher: statePublisher
                            )
                        }
                    }
                    try await persistentState.loadIfNeeded(
                        id: persistenceKey,
                        store: persistentStore
                    )
                    await activation.activated()
                    try await policy.didActivate(address: address)
                    return activation
                } catch {
                    persistentState.forget(id: persistenceKey)
                    for binding in activation.remoteStateBindings {
                        await binding.unbind()
                    }
                    registration.factory.passivate(address: address)
                    throw error
                }
            } catch {
                if let systemError = error as? ActorSystemError,
                   systemError.code == .activationFailed {
                    throw systemError
                }
                await policy.activationFailed(address: address, error: error)
                throw error
            }
        }
        activationTasks[address] = task
        let activation: SwiftWebActivatedActor
        do {
            activation = try await task.value
        } catch {
            activationTasks[address] = nil
            activationReservations.remove(address)
            throw error
        }
        guard canInstallActivation(at: address) else {
            throw ActorSystemError.activationFailed
        }
        activationTasks[address] = nil
        activationReservations.remove(address)
        installActivationIfNeeded(activation, at: address)
    }

    private func installActivationIfNeeded(
        _ activation: SwiftWebActivatedActor,
        at address: ActorAddress
    ) {
        guard activeActors[address] == nil else {
            return
        }
        activeActors[address] = HostedActor(
            activation: activation,
            gate: SwiftWebActorInvocationGate(),
            lastAccess: Date(),
            pendingInvocations: 0
        )
    }

    private func canInstallActivation(at address: ActorAddress) -> Bool {
        phase == .accepting
            && factories[address.type] != nil
            && !unregisteringActorTypes.contains(address.type)
    }

    private func reserveActivationCapacity(for address: ActorAddress) async throws {
        if activationReservations.contains(address) {
            return
        }
        guard activationPolicy.maximumVirtualActorCount > 0 else {
            throw ActorSystemError.overloaded
        }
        let now = Date()
        let expired = activeActors.compactMap { candidate, hosted -> ActorAddress? in
            guard hosted.isVirtual,
                  hosted.pendingInvocations == 0,
                  let timeout = idleTimeout(for: candidate),
                  now.timeIntervalSince(hosted.lastAccess) >= timeout
            else {
                return nil
            }
            return candidate
        }
        for candidate in expired where candidate != address {
            try await passivate(address: candidate)
        }

        while virtualActorCount + activationReservations.count
            >= activationPolicy.maximumVirtualActorCount {
            let candidate = activeActors
                .filter {
                    $0.key != address
                        && $0.value.isVirtual
                        && $0.value.pendingInvocations == 0
                }
                .min(by: { $0.value.lastAccess < $1.value.lastAccess })
                .map(\.key)
            guard let candidate else {
                throw ActorSystemError.overloaded
            }
            try await passivate(address: candidate)
        }
        activationReservations.insert(address)
    }

    private var virtualActorCount: Int {
        activeActors.values.reduce(into: 0) { count, hosted in
            if hosted.isVirtual {
                count += 1
            }
        }
    }

    private func startPassivation(
        address: ActorAddress,
        hosted: HostedActor
    ) async throws {
        guard let activation = hosted.activation,
              let registration = factories[address.type]
        else {
            throw SwiftWebActorHostError.factoryNotFound(address.type)
        }
        cancelIdleTask(for: address)
        activeActors[address] = nil
        passivatingActors[address] = hosted
        let policy = self.policy
        let persistentState = self.persistentState
        let persistentStore = self.persistentStore
        let statePublisher = self.statePublisher
        let persistenceKey = Self.persistenceKey(for: address)
        let task = makeOwnedThrowingTask {
            try await policy.willPassivate(address: address)
            await activation.passivating()
            try await persistentState.save(
                id: persistenceKey,
                store: persistentStore
            )
            registration.factory.passivate(address: address)
            persistentState.forget(id: persistenceKey)
            for binding in activation.remoteStateBindings {
                await binding.unbind()
            }
            if let statePublisher {
                await statePublisher.finish(actorAddress: address)
            }
        }
        passivationTasks[address] = task
        do {
            try await task.value
            passivationTasks[address] = nil
            passivatingActors[address] = nil
        } catch {
            passivationTasks[address] = nil
            if phase == .accepting,
               !unregisteringActorTypes.contains(address.type) {
                let restored = passivatingActors.removeValue(forKey: address)
                if let restored {
                    activeActors[address] = restored
                    scheduleIdlePassivation(for: address)
                }
            }
            await policy.passivationFailed(address: address, error: error)
            throw error
        }
    }

    private func forcePassivate(
        address: ActorAddress,
        hosted: HostedActor,
        registration: FactoryRegistration
    ) async throws {
        guard let activation = hosted.activation else {
            return
        }
        var passivationFailure: (any Error)?
        do {
            try await policy.willPassivate(address: address)
            await activation.passivating()
            try await persistentState.save(
                id: Self.persistenceKey(for: address),
                store: persistentStore
            )
        } catch {
            await policy.passivationFailed(address: address, error: error)
            passivationFailure = error
        }
        registration.factory.passivate(address: address)
        persistentState.forget(id: Self.persistenceKey(for: address))
        for binding in activation.remoteStateBindings {
            await binding.unbind()
        }
        if let statePublisher {
            await statePublisher.finish(actorAddress: address)
        }
        if let passivationFailure {
            throw passivationFailure
        }
    }

    private func releaseInvocationReservation(for address: ActorAddress) {
        guard var hosted = activeActors[address] else {
            return
        }
        precondition(
            hosted.pendingInvocations > 0,
            "Actor invocation reservation count underflow"
        )
        hosted.pendingInvocations -= 1
        hosted.lastAccess = Date()
        activeActors[address] = hosted
        if hosted.pendingInvocations == 0 {
            scheduleIdlePassivation(for: address)
        }
    }

    private func idleTimeout(for address: ActorAddress) -> TimeInterval? {
        factories[address.type]?.passivation?.idleTimeout
            ?? activationPolicy.idleTimeout
    }

    private func scheduleIdlePassivation(for address: ActorAddress) {
        cancelIdleTask(for: address)
        guard phase == .accepting,
              let hosted = activeActors[address],
              hosted.isVirtual,
              hosted.pendingInvocations == 0,
              let timeout = idleTimeout(for: address)
        else {
            return
        }
        let lastAccess = hosted.lastAccess
        idleTasks[address] = makeOwnedTask {
            do {
                try await Task.sleep(for: .seconds(max(0, timeout)))
            } catch {
                return
            }
            await self.passivateIfIdle(
                address: address,
                lastAccess: lastAccess
            )
        }
    }

    private func passivateIfIdle(
        address: ActorAddress,
        lastAccess: Date
    ) async {
        idleTasks[address] = nil
        guard phase == .accepting,
              let hosted = activeActors[address],
              hosted.isVirtual,
              hosted.pendingInvocations == 0,
              hosted.lastAccess == lastAccess
        else {
            return
        }
        do {
            try await passivate(address: address)
        } catch {
            // The policy receives the failure and the active actor is restored.
        }
    }

    private func makeOwnedThrowingTask<Success: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Success
    ) -> Task<Success, any Error> {
        let taskOwner = ownedTaskOwner
        return Task {
            try await SwiftWebActorHostTaskContext.$owner.withValue(
                taskOwner
            ) {
                try await operation()
            }
        }
    }

    private func makeOwnedTask(
        _ operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        let taskOwner = ownedTaskOwner
        return Task {
            await SwiftWebActorHostTaskContext.$owner.withValue(
                taskOwner
            ) {
                await operation()
            }
        }
    }

    private func cancelIdleTask(for address: ActorAddress) {
        idleTasks.removeValue(forKey: address)?.cancel()
    }

    private func cancelAllIdleTasks() {
        let tasks = idleTasks.values
        idleTasks.removeAll(keepingCapacity: false)
        for task in tasks {
            task.cancel()
        }
    }

    private func finishInvocation() {
        precondition(inFlightInvocations > 0, "Actor host invocation count underflow")
        inFlightInvocations -= 1
        guard inFlightInvocations == 0 else {
            return
        }
        let waiters = drainWaiters
        drainWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
    }

    private static func persistenceKey(for address: ActorAddress) -> String {
        let high = String(address.type.high, radix: 16)
        let low = String(address.type.low, radix: 16)
        return "v1:\(high):\(low):\(address.identity.utf8.count):\(address.identity)"
    }
}

private actor SwiftWebActorInvocationGate {
    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var isHeld = false
    private var nextWaiterID: UInt64 = 0
    private var waiters: [Waiter] = []

    func acquire() async throws {
        guard !Task.isCancelled else {
            throw ActorSystemError.cancelled
        }
        if !isHeld {
            isHeld = true
            return
        }

        guard nextWaiterID < UInt64.max else {
            throw ActorSystemError.overloaded
        }
        nextWaiterID += 1
        let waiterID = nextWaiterID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: ActorSystemError.cancelled)
                    return
                }
                waiters.append(
                    Waiter(id: waiterID, continuation: continuation)
                )
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
        if Task.isCancelled {
            release()
            throw ActorSystemError.cancelled
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume()
    }

    private func cancelWaiter(id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: ActorSystemError.cancelled)
    }
}
#endif
