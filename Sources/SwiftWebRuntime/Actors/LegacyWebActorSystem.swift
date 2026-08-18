#if SWIFTWEB_LEGACY_ACTORS
@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
@preconcurrency import ActorSystemCompatibility
@preconcurrency import Distributed
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML
import Synchronization

@available(*, deprecated, message: "Use WebActorSystem and the binary actor frame transport")
public final class LegacyWebActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = String
    public typealias InvocationEncoder = WebActorInvocationEncoder
    public typealias InvocationDecoder = WebActorInvocationDecoder
    public typealias ResultHandler = WebActorResultHandler
    public typealias SerializationRequirement = Codable & Sendable

    public static let shared = LegacyWebActorSystem()

    private struct ReminderStoreRegistration: Sendable {
        let store: any WebActorReminderStore
        let ownership: WebActorResourceOwnership
    }

    private enum Phase: Sendable {
        case accepting
        case stopping
        case stopped
    }

    private struct LifecycleState: Sendable {
        var phase = Phase.accepting
        var inFlight = 0
        var drainWaiters: [CheckedContinuation<Void, Never>] = []
        var termination: ActorSystemTermination?
    }

    private final class ShutdownDependencyResolver: Sendable {
        private struct State: Sendable {
            var dependencies: [ActorSystemTermination]?
            var waiter: CheckedContinuation<[ActorSystemTermination], Never>?
        }

        private let state = Mutex(State())

        func wait() async -> [ActorSystemTermination] {
            if let dependencies = state.withLock({ $0.dependencies }) {
                return dependencies
            }
            return await withCheckedContinuation { continuation in
                let dependencies = state.withLock {
                    state -> [ActorSystemTermination]? in
                    guard state.dependencies == nil else {
                        return state.dependencies
                    }
                    state.waiter = continuation
                    return nil
                }
                if let dependencies {
                    continuation.resume(returning: dependencies)
                }
            }
        }

        func resolve(_ dependencies: [ActorSystemTermination]) {
            let waiter = state.withLock {
                state -> CheckedContinuation<[ActorSystemTermination], Never>? in
                guard state.dependencies == nil else {
                    return nil
                }
                state.dependencies = dependencies
                let waiter = state.waiter
                state.waiter = nil
                return waiter
            }
            waiter?.resume(returning: dependencies)
        }
    }

    private struct ShutdownRequest: Sendable {
        let termination: ActorSystemTermination
        let resolver: ShutdownDependencyResolver?
    }

    private enum WorkContext {
        @TaskLocal static var system: LegacyWebActorSystem?
    }

    private let registry = ActorRegistry()
    private let transportBox: Mutex<(any WebActorTransport)?>
    private let activators = Mutex<[String: WebActorActivator]>([:])
    private let scopeAuthorizations = Mutex<[String: WebActorAuthorization]>([:])
    private let passivationPolicies = Mutex<[String: ActorPassivationPolicy]>([:])
    private let reminderStoreBox = Mutex<ReminderStoreRegistration?>(nil)
    private let statePublisherBox = Mutex<(any WebActorStatePublisher)?>(nil)
    private let activationRecords = Mutex<[ActorID: WebActorActivationRecord]>([:])
    private let activationLock = Mutex<Void>(())
    private let persistentStoreBox: Mutex<(any WebActorPersistentStore)?>
    private let persistentState = ActorPersistentStateRegistry()
    private let lifecycle = Mutex(LifecycleState())

    /// Creates a compatibility system with an optional borrowed transport.
    /// `WebActorTransport` has no lifecycle contract, so the system releases
    /// its reference at shutdown but never assumes authority to stop it.
    public init(transport: (any WebActorTransport)? = nil) {
        self.transportBox = Mutex(transport)
        self.persistentStoreBox = Mutex(nil)
    }

    /// Installs the borrowed store that backs `@ActorStorage` grain state.
    /// The persistence protocol has no lifecycle operation; shutdown completes
    /// outstanding saves and releases this reference without stopping the store.
    /// Without one,
    /// `@ActorStorage` values are in-memory only (no durability). The Cloudflare
    /// host installs a Durable Object-backed store; native hosts can install any
    /// durable store, or `InMemoryActorPersistentStore` for a process-lifetime one.
    public func setPersistentStore(_ store: any WebActorPersistentStore) {
        withAcceptingMutation {
            persistentStoreBox.withLock { $0 = store }
        }
    }

    private var persistentStore: (any WebActorPersistentStore)? {
        persistentStoreBox.withLock { $0 }
    }

    /// Installs a borrowed transport for outbound calls to non-local actors.
    /// Hosts that learn their routing after construction (the Durable Object
    /// host wiring WebSocket sessions) use this; it replaces and releases the
    /// reference to any prior transport without claiming its lifecycle.
    public func setTransport(_ transport: any WebActorTransport) {
        withAcceptingMutation {
            transportBox.withLock { $0 = transport }
        }
    }

    private var transport: (any WebActorTransport)? {
        transportBox.withLock { $0 }
    }

    /// The contract prefix identifying an actor type in virtual-actor IDs
    /// (`"<contract>:<name>"`), matching the prefix `assignID` generates.
    public static func contract<Act: DistributedActor>(for actorType: Act.Type) -> String {
        String(reflecting: actorType)
    }

    /// The ID addressing the virtual actor of the given type with the given
    /// logical name. Sending to it activates the actor on demand when an
    /// `ActorGroup` for the type is registered.
    public static func actorID<Act: DistributedActor>(for actorType: Act.Type, named name: String) -> ActorID {
        "\(contract(for: actorType)):\(name)"
    }

    /// Registers the factory that activates instances of `actorType` on
    /// demand, one per ID. Registered by `ActorGroup` during scene lowering.
    /// The environment is established around activation and every invocation
    /// on the group's actors, so `@Environment` resolves inside them.
    public func registerActivator<Act: DistributedActor>(
        for actorType: Act.Type,
        environment: EnvironmentValues = EnvironmentValues(),
        activate: @escaping @Sendable () -> Void
    ) where Act.ActorSystem == LegacyWebActorSystem {
        let activator = WebActorActivator(environment: environment, activate: activate)
        withAcceptingMutation {
            activators.withLock { $0[Self.contract(for: actorType)] = activator }
        }
    }

    /// Registers the scope-implied authorization for a contract. Registered
    /// by `ActorGroup` when the group declares an `ActorScope`; applied to
    /// every external invocation addressed to the contract, after the
    /// app-level authorizer allows the request.
    public func registerScopeAuthorization(_ authorization: WebActorAuthorization, forContract contract: String) {
        withAcceptingMutation {
            scopeAuthorizations.withLock { $0[contract] = authorization }
        }
    }

    /// Registers a per-contract passivation policy. Registered by
    /// `ActorGroup` when the group declares one; overrides the host-level
    /// `WebActorActivationPolicy.idleTimeout` for that contract.
    public func registerPassivationPolicy(_ policy: ActorPassivationPolicy, forContract contract: String) {
        withAcceptingMutation {
            passivationPolicies.withLock { $0[contract] = policy }
        }
    }

    private func scopeAuthorization(for recipient: WebActorRecipient) -> WebActorAuthorization? {
        guard let contract = recipient.contract else {
            return nil
        }
        return scopeAuthorizations.withLock { $0[contract] }
    }

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID where Act: DistributedActor {
        requireAcceptingOrOwnedWork()
        if let pending = WebActorActivationContext.current?.takeIfMatching(contract: Self.contract(for: actorType)) {
            return pending
        }
        return "\(String(reflecting: actorType)):\(UUID().uuidString)"
    }

    public func actorReady<Act>(_ actor: Act) where Act: DistributedActor, Act.ID == ActorID {
        withAcceptingMutation {
            registry.register(actor, id: actor.id)
        }
    }

    public func resignID(_ id: ActorID) {
        activationRecords.withLock { $0[id] = nil }
        persistentState.forget(id: id)
        registry.unregister(id: id)
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorID {
        try lifecycle.withLock { state in
            guard state.phase == .accepting || WorkContext.system === self else {
                throw ActorSystemError.shuttingDown
            }
            return registry.find(id: id) as? Act
        }
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        WebActorInvocationEncoder()
    }

    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res where Act: DistributedActor, Act.ID == ActorID, Err: Error, Res: Codable & Sendable {
        try beginWork()
        defer { finishWork() }
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
        return try await WorkContext.$system.withValue(self) {
            let response = try await dispatch(envelope: envelope, target: target)

            switch response.result {
            case .success(let data):
                return try JSONDecoder().decode(Res.self, from: data)
            case .void:
                guard Res.self == Void.self else {
                    throw RuntimeError.executionFailed("Expected \(Res.self), but invocation returned Void", underlying: "Type mismatch")
                }
                return () as! Res
            case .failure(let error):
                throw error
            }
        }
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws where Act: DistributedActor, Act.ID == ActorID, Err: Error {
        try beginWork()
        defer { finishWork() }
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
        try await WorkContext.$system.withValue(self) {
            let response = try await dispatch(envelope: envelope, target: target)

            switch response.result {
            case .void:
                return
            case .success:
                throw RuntimeError.executionFailed("Expected Void, but invocation returned a value", underlying: "Type mismatch")
            case .failure(let error):
                throw error
            }
        }
    }

    public func invoke(
        actorID: ActorID,
        targetIdentifier: String,
        arguments: [Data]
    ) async throws -> ResponseEnvelope {
        let envelope = InvocationEnvelope(
            recipientID: actorID,
            target: targetIdentifier,
            arguments: arguments
        )
        return try await invoke(envelope: envelope)
    }

    public func invoke(envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        try beginWork()
        defer { finishWork() }
        return try await WorkContext.$system.withValue(self) {
            try await execute(
                envelope: envelope,
                target: RemoteCallTarget(envelope.target),
                activationPolicy: .unbounded
            )
        }
    }

    public func invoke(
        envelope: InvocationEnvelope,
        context: WebActorInvocationContext,
        authorization: WebActorAuthorization,
        activationPolicy: WebActorActivationPolicy = .defaults
    ) async throws -> ResponseEnvelope {
        try beginWork()
        defer { finishWork() }
        return try await WorkContext.$system.withValue(self) {
            let target = RemoteCallTarget(envelope.target)
            let recipient = WebActorRecipient(actorID: envelope.recipientID)
            let state = actorAuthorizationState(for: recipient)
            let request = WebActorAuthorizationRequest(
                envelope: envelope,
                recipient: recipient,
                targetIdentifier: envelope.target,
                context: context,
                isRegistered: state.isRegistered,
                isVirtualActor: state.isVirtualActor
            )
            switch await authorization.authorize(request) {
            case .allow:
                break
            case .deny(let reason):
                throw WebActorAuthorizationError(reason)
            }
            if let scoped = scopeAuthorization(for: recipient) {
                switch await scoped.authorize(request) {
                case .allow:
                    break
                case .deny(let reason):
                    throw WebActorAuthorizationError(reason)
                }
            }
            return try await execute(
                envelope: envelope,
                target: target,
                activationPolicy: activationPolicy
            )
        }
    }

    public func requestShutdown() -> ActorSystemTermination {
        let request = lifecycle.withLock { state -> ShutdownRequest in
            if let termination = state.termination {
                return ShutdownRequest(termination: termination, resolver: nil)
            }
            state.phase = .stopping
            let resolver = ShutdownDependencyResolver()
            let termination = ActorSystemTermination(
                waitIsReentrant: { WorkContext.system === self },
                dependencies: {
                    await resolver.wait()
                },
                operation: {
                    try await WorkContext.$system.withValue(self) {
                        await self.waitForDrain()
                        defer {
                            self.lifecycle.withLock { $0.phase = .stopped }
                        }
                        try await self.releaseOwnedResources()
                    }
                }
            )
            state.termination = termination
            return ShutdownRequest(termination: termination, resolver: resolver)
        }
        if let resolver = request.resolver {
            let ownedReminderStore = reminderStoreBox.withLock {
                registration -> (any WebActorReminderStore)? in
                guard let registration, registration.ownership == .owned else {
                    return nil
                }
                return registration.store
            }
            let reminderTermination = ownedReminderStore?.requestShutdown()
            resolver.resolve(reminderTermination.map { [$0] } ?? [])
        }
        return request.termination
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    private func beginWork() throws {
        try lifecycle.withLock { state in
            guard state.phase == .accepting else {
                throw ActorSystemError.shuttingDown
            }
            state.inFlight += 1
        }
    }

    private func finishWork() {
        let waiters = lifecycle.withLock {
            state -> [CheckedContinuation<Void, Never>] in
            precondition(state.inFlight > 0, "Legacy actor work count underflow")
            state.inFlight -= 1
            guard state.inFlight == 0 else {
                return []
            }
            let waiters = state.drainWaiters
            state.drainWaiters.removeAll(keepingCapacity: false)
            return waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func waitForDrain() async {
        if lifecycle.withLock({ $0.inFlight == 0 }) {
            return
        }
        await withCheckedContinuation { continuation in
            let shouldResume = lifecycle.withLock { state -> Bool in
                guard state.inFlight > 0 else {
                    return true
                }
                state.drainWaiters.append(continuation)
                return false
            }
            if shouldResume {
                continuation.resume()
            }
        }
    }

    private func releaseOwnedResources() async throws {
        let actorIDs = activationRecords.withLock { records in
            let actorIDs = Array(records.keys)
            records.removeAll(keepingCapacity: false)
            return actorIDs
        }
        let evictions = unregisterCapturingInstances(ids: actorIDs)
        let store = persistentStore
        var firstFailure: (any Error)?

        for eviction in evictions {
            if let actorLifecycle = eviction.instance as? any WebActorLifecycle {
                await Self.runPassivatingHook(on: actorLifecycle)
            }
            do {
                try await persistentState.save(id: eviction.id, store: store)
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
            }
            persistentState.forget(id: eviction.id)
        }

        registry.clear()
        persistentState.removeAll()
        reminderStoreBox.withLock { $0 = nil }
        transportBox.withLock { $0 = nil }
        activators.withLock { $0.removeAll(keepingCapacity: false) }
        scopeAuthorizations.withLock { $0.removeAll(keepingCapacity: false) }
        passivationPolicies.withLock { $0.removeAll(keepingCapacity: false) }
        statePublisherBox.withLock { $0 = nil }
        persistentStoreBox.withLock { $0 = nil }

        if let firstFailure {
            throw firstFailure
        }
    }

    private func withAcceptingMutation(_ operation: () -> Void) {
        lifecycle.withLock { state in
            precondition(
                state.phase == .accepting || WorkContext.system === self,
                "Legacy actor system is shutting down"
            )
            operation()
        }
    }

    private func requireAcceptingOrOwnedWork() {
        lifecycle.withLock { state in
            precondition(
                state.phase == .accepting || WorkContext.system === self,
                "Legacy actor system is shutting down"
            )
        }
    }

    private func dispatch(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget
    ) async throws -> ResponseEnvelope {
        if registry.find(id: envelope.recipientID) != nil {
            return try await execute(envelope: envelope, target: target, activationPolicy: .unbounded)
        }

        guard let transport else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }
        return try await transport.call(envelope)
    }

    private func execute(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget,
        activationPolicy: WebActorActivationPolicy
    ) async throws -> ResponseEnvelope {
        #if !hasFeature(Embedded)
        if let environment = registeredEnvironment(for: envelope.recipientID) {
            return try await EnvironmentValues.withValue(environment) {
                try await self.executeResolved(
                    envelope: envelope,
                    target: target,
                    activationPolicy: activationPolicy
                )
            }
        }
        #endif
        return try await executeResolved(
            envelope: envelope,
            target: target,
            activationPolicy: activationPolicy
        )
    }

    private func registeredEnvironment(for id: ActorID) -> EnvironmentValues? {
        guard let separator = id.firstIndex(of: ":") else {
            return nil
        }
        return activators.withLock { $0[String(id[..<separator])] }?.environment
    }

    private func executeResolved(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget,
        activationPolicy: WebActorActivationPolicy
    ) async throws -> ResponseEnvelope {
        let now = Date()
        let registeredActor = registry.find(id: envelope.recipientID)
        if registeredActor != nil {
            markVirtualActorAccess(id: envelope.recipientID, at: now)
        }
        var wasActivated = false
        var evictions: [WebActorEviction] = []
        let resolvedActor: (any DistributedActor)?
        if let registeredActor {
            resolvedActor = registeredActor
        } else {
            let activation = try activatedActor(
                id: envelope.recipientID,
                activationPolicy: activationPolicy,
                now: now
            )
            resolvedActor = activation.actor
            wasActivated = activation.wasActivated
            evictions = activation.evictions
        }
        guard let actor = resolvedActor else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }

        // Passivate evicted instances outside the activation lock: run their
        // hooks and persist any grain state the hooks mutated.
        try await runPassivation(for: evictions)

        // Restore grain state before the first dispatch sees the actor.
        try await persistentState.loadIfNeeded(id: envelope.recipientID, store: persistentStore)

        // The activation hook runs after grain state is restored, so cold
        // start and resume observe the same, fully rehydrated actor.
        if wasActivated, let lifecycle = actor as? any WebActorLifecycle {
            await Self.runActivatedHook(on: lifecycle)
        }

        var decoder = try WebActorInvocationDecoder(envelope: envelope)
        let resultStore = WebActorInvocationResultStore()
        let handler = WebActorResultHandler(callID: envelope.callID) { response in
            await resultStore.store(response)
        }

        try await executeDistributedTarget(
            on: actor,
            target: target,
            invocationDecoder: &decoder,
            handler: handler
        )

        // Persist grain state after the invocation. A save failure fails the
        // call rather than silently dropping the mutation.
        try await persistentState.save(id: envelope.recipientID, store: persistentStore)

        guard let response = await resultStore.response else {
            throw RuntimeError.executionFailed("No result captured", underlying: "Unknown")
        }
        return response
    }

    /// Activates the virtual actor an ID targets when an `ActorGroup` factory
    /// is registered for its contract. The lock makes activation per-ID
    /// single-flight: concurrent messages for the same ID get one instance.
    private func activatedActor(
        id: ActorID,
        activationPolicy: WebActorActivationPolicy,
        now: Date
    ) throws -> WebActorActivationResult {
        guard let separator = id.firstIndex(of: ":") else {
            return WebActorActivationResult(actor: nil, wasActivated: false, evictions: [])
        }
        let contract = String(id[..<separator])
        guard let activator = activators.withLock({ $0[contract] }) else {
            return WebActorActivationResult(actor: nil, wasActivated: false, evictions: [])
        }
        return try activationLock.withLock { _ in
            if let existing = registry.find(id: id) {
                markVirtualActorAccess(id: id, at: now)
                return WebActorActivationResult(actor: existing, wasActivated: false, evictions: [])
            }
            guard activationPolicy.maximumVirtualActorCount > 0 else {
                throw RuntimeError.transportFailed("Virtual actor activation is disabled")
            }
            var evictions = purgeExpiredVirtualActors(now: now, policy: activationPolicy)
            evictions.append(contentsOf: evictLeastRecentlyUsedVirtualActorsIfNeeded(policy: activationPolicy))
            let storageCollector = ActorStorageActivationContext.Collector()
            let remoteStateCollector = RemoteStateActivationContext.Collector()
            WebActorActivationContext.withValue(WebActorPendingID(id)) {
                ActorStorageActivationContext.withValue(storageCollector) {
                    RemoteStateActivationContext.withValue(remoteStateCollector) {
                        activator.activate()
                    }
                }
            }
            guard let activated = registry.find(id: id) else {
                throw RuntimeError.executionFailed(
                    "ActorGroup factory did not create a \(contract) on this actor system for id '\(id)'",
                    underlying: "The factory must construct the actor with the app's actor system"
                )
            }
            try persistentState.bind(id: id, boxes: storageCollector.collected())
            if let statePublisher = statePublisherBox.withLock({ $0 }) {
                for box in remoteStateCollector.collected() {
                    box.bind(actorID: id, publisher: statePublisher)
                }
            }
            recordVirtualActor(id: id, contract: contract, at: now)
            return WebActorActivationResult(actor: activated, wasActivated: true, evictions: evictions)
        }
    }

    private func actorAuthorizationState(
        for recipient: WebActorRecipient
    ) -> (isRegistered: Bool, isVirtualActor: Bool) {
        let isRegistered = registry.find(id: recipient.actorID) != nil
        let isTrackedVirtual = activationRecords.withLock { $0[recipient.actorID] != nil }
        let canActivate = recipient.contract.map { contract in
            activators.withLock { $0[contract] != nil }
        } ?? false
        return (
            isRegistered: isRegistered,
            isVirtualActor: isTrackedVirtual || (!isRegistered && canActivate)
        )
    }

    private func recordVirtualActor(id: ActorID, contract: String, at date: Date) {
        activationRecords.withLock { records in
            records[id] = WebActorActivationRecord(id: id, contract: contract, lastAccess: date)
        }
    }

    private func markVirtualActorAccess(id: ActorID, at date: Date) {
        activationRecords.withLock { records in
            guard var record = records[id] else {
                return
            }
            record.lastAccess = date
            records[id] = record
        }
    }

    private func purgeExpiredVirtualActors(now: Date, policy: WebActorActivationPolicy) -> [WebActorEviction] {
        let contractPolicies = passivationPolicies.withLock { $0 }
        guard policy.idleTimeout != nil || !contractPolicies.isEmpty else {
            return []
        }
        let expiredIDs = activationRecords.withLock { records in
            let expiredIDs = records.values
                .filter { record in
                    let timeout = contractPolicies[record.contract]?.idleTimeout ?? policy.idleTimeout
                    guard let timeout else {
                        return false
                    }
                    return now.timeIntervalSince(record.lastAccess) >= timeout
                }
                .map(\.id)
            for id in expiredIDs {
                records[id] = nil
            }
            return expiredIDs
        }
        return unregisterCapturingInstances(ids: expiredIDs)
    }

    private func evictLeastRecentlyUsedVirtualActorsIfNeeded(
        policy: WebActorActivationPolicy
    ) -> [WebActorEviction] {
        guard policy.maximumVirtualActorCount < Int.max else {
            return []
        }
        let evictedIDs = activationRecords.withLock { records in
            guard records.count >= policy.maximumVirtualActorCount else {
                return [] as [ActorID]
            }
            let removalCount = records.count - policy.maximumVirtualActorCount + 1
            let evictedIDs = records.values
                .sorted { left, right in left.lastAccess < right.lastAccess }
                .prefix(removalCount)
                .map(\.id)
            for id in evictedIDs {
                records[id] = nil
            }
            return evictedIDs
        }
        return unregisterCapturingInstances(ids: evictedIDs)
    }

    /// Unregisters the given IDs, capturing each live instance so the caller
    /// can run its `passivating()` hook outside the activation lock. The
    /// durable grain state is intentionally left in place: passivation
    /// evicts the instance, not the identity.
    private func unregisterCapturingInstances(ids: [ActorID]) -> [WebActorEviction] {
        ids.map { id in
            let instance = registry.find(id: id)
            registry.unregister(id: id)
            return WebActorEviction(id: id, instance: instance)
        }
    }

    /// Runs `passivating()` hooks for evicted instances and persists any
    /// grain state the hook mutated. A save failure propagates: dropping a
    /// mutation silently is worse than failing the triggering call.
    private func runPassivation(for evictions: [WebActorEviction]) async throws {
        for eviction in evictions {
            guard let lifecycle = eviction.instance as? any WebActorLifecycle else {
                continue
            }
            await Self.runPassivatingHook(on: lifecycle)
            try await persistentState.save(id: eviction.id, store: persistentStore)
        }
    }

    /// Lifecycle hooks are ordinary (non-distributed) actor methods, so they
    /// can only be invoked through `whenLocal`. Instances reached here are
    /// always local: they were activated or registered on this system.
    private static func runActivatedHook(on lifecycle: some WebActorLifecycle) async {
        await lifecycle.whenLocal { isolated in
            await isolated.activated()
        }
    }

    private static func runPassivatingHook(on lifecycle: some WebActorLifecycle) async {
        await lifecycle.whenLocal { isolated in
            await isolated.passivating()
        }
    }

    /// Installs the publisher that fans `@RemoteState` changes out to
    /// observing clients. The WebSocket host routes changes to observer
    /// peers; without a publisher, `@RemoteState` values stay local.
    public func setStatePublisher(_ publisher: any WebActorStatePublisher) {
        withAcceptingMutation {
            statePublisherBox.withLock { $0 = publisher }
        }
    }

    /// Installs the durable reminder backend. The Cloudflare host lowers
    /// reminders onto Durable Object Alarms; native hosts can install
    /// `InProcessActorReminderStore` for process-lifetime scheduling.
    public func setReminderStore(
        _ store: any WebActorReminderStore,
        ownership: WebActorResourceOwnership = .owned
    ) async throws {
        let previous = try lifecycle.withLock {
            state -> ReminderStoreRegistration? in
            guard state.phase == .accepting else {
                throw ActorSystemError.shuttingDown
            }
            return reminderStoreBox.withLock { registration in
                let previous = registration
                registration = ReminderStoreRegistration(
                    store: store,
                    ownership: ownership
                )
                return previous
            }
        }
        if let previous, previous.ownership == .owned {
            try await previous.store.shutdown()
        }
    }

    /// The reminder handle for an actor identity.
    public func reminders(for id: ActorID) -> WebActorReminders {
        WebActorReminders(
            actorID: id,
            store: reminderStoreBox.withLock { $0?.store }
        )
    }

    /// Delivers a fired reminder: re-activates the actor when passivated
    /// (restoring grain state and running `activated()`), invokes
    /// `WebActorRemindable.reminder(_:)`, and persists state the handler
    /// mutated. Delivery to a non-remindable actor throws.
    public func deliverReminder(_ reminder: WebActorReminder) async throws {
        try beginWork()
        defer { finishWork() }
        return try await WorkContext.$system.withValue(self) {
            #if !hasFeature(Embedded)
            if let environment = registeredEnvironment(for: reminder.actorID) {
                return try await EnvironmentValues.withValue(environment) {
                    try await self.deliverResolvedReminder(reminder)
                }
            }
            #endif
            return try await deliverResolvedReminder(reminder)
        }
    }

    private func deliverResolvedReminder(_ reminder: WebActorReminder) async throws {
        let now = Date()
        var wasActivated = false
        var evictions: [WebActorEviction] = []
        let resolvedActor: (any DistributedActor)?
        if let registered = registry.find(id: reminder.actorID) {
            markVirtualActorAccess(id: reminder.actorID, at: now)
            resolvedActor = registered
        } else {
            let activation = try activatedActor(id: reminder.actorID, activationPolicy: .defaults, now: now)
            resolvedActor = activation.actor
            wasActivated = activation.wasActivated
            evictions = activation.evictions
        }
        guard let actor = resolvedActor else {
            throw RuntimeError.actorNotFound(reminder.actorID)
        }
        try await runPassivation(for: evictions)
        try await persistentState.loadIfNeeded(id: reminder.actorID, store: persistentStore)
        if wasActivated, let lifecycle = actor as? any WebActorLifecycle {
            await Self.runActivatedHook(on: lifecycle)
        }
        guard let remindable = actor as? any WebActorRemindable else {
            throw WebActorReminderError.actorNotRemindable(actorID: reminder.actorID, name: reminder.name)
        }
        try await Self.runReminderHook(on: remindable, name: reminder.name)
        try await persistentState.save(id: reminder.actorID, store: persistentStore)
    }

    private static func runReminderHook(on remindable: some WebActorRemindable, name: String) async throws {
        try await remindable.whenLocal { isolated in
            try await isolated.reminder(name)
        }
    }
}

/// An evicted virtual actor: its ID and, when it was still registered, the
/// live instance whose `passivating()` hook should run.
private struct WebActorEviction: Sendable {
    let id: LegacyWebActorSystem.ActorID
    let instance: (any DistributedActor)?
}

/// The outcome of resolving a virtual actor for an invocation: the resolved
/// instance, whether this call activated it, and instances evicted to make
/// room, whose passivation hooks run outside the activation lock.
private struct WebActorActivationResult: Sendable {
    let actor: (any DistributedActor)?
    let wasActivated: Bool
    let evictions: [WebActorEviction]
}

private struct WebActorActivator: Sendable {
    let environment: EnvironmentValues
    let activate: @Sendable () -> Void
}

private struct WebActorActivationRecord: Sendable {
    let id: LegacyWebActorSystem.ActorID
    let contract: String
    var lastAccess: Date
}

private actor WebActorInvocationResultStore {
    private var storedResponse: ResponseEnvelope?

    var response: ResponseEnvelope? {
        storedResponse
    }

    func store(_ response: ResponseEnvelope) {
        storedResponse = response
    }
}
#endif
