@preconcurrency import ActorRuntime
@preconcurrency import Distributed
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML
import Synchronization

public final class WebActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = String
    public typealias InvocationEncoder = WebActorInvocationEncoder
    public typealias InvocationDecoder = WebActorInvocationDecoder
    public typealias ResultHandler = WebActorResultHandler
    public typealias SerializationRequirement = Codable & Sendable

    public static let shared = WebActorSystem()

    private let registry = ActorRegistry()
    private let transportBox: Mutex<(any WebActorTransport)?>
    private let activators = Mutex<[String: WebActorActivator]>([:])
    private let activationLock = Mutex<Void>(())

    public init(transport: (any WebActorTransport)? = nil) {
        self.transportBox = Mutex(transport)
    }

    /// Installs the transport for outbound calls to non-local actors. Hosts
    /// that learn their routing after construction (the Durable Object host
    /// wiring WebSocket sessions) use this; it replaces any prior transport.
    public func setTransport(_ transport: any WebActorTransport) {
        transportBox.withLock { $0 = transport }
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
    ) where Act.ActorSystem == WebActorSystem {
        let activator = WebActorActivator(environment: environment, activate: activate)
        activators.withLock { $0[Self.contract(for: actorType)] = activator }
    }

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID where Act: DistributedActor {
        if let pending = WebActorActivationContext.current?.takeIfMatching(contract: Self.contract(for: actorType)) {
            return pending
        }
        return "\(String(reflecting: actorType)):\(UUID().uuidString)"
    }

    public func actorReady<Act>(_ actor: Act) where Act: DistributedActor, Act.ID == ActorID {
        registry.register(actor, id: actor.id)
    }

    public func resignID(_ id: ActorID) {
        registry.unregister(id: id)
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorID {
        registry.find(id: id) as? Act
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
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
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

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws where Act: DistributedActor, Act.ID == ActorID, Err: Error {
        invocation.recordTarget(target)
        let envelope = try invocation.makeInvocationEnvelope(recipientID: actor.id)
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
        try await execute(
            envelope: envelope,
            target: RemoteCallTarget(envelope.target)
        )
    }

    public func shutdown() {
        registry.clear()
    }

    private func dispatch(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget
    ) async throws -> ResponseEnvelope {
        if registry.find(id: envelope.recipientID) != nil {
            return try await execute(envelope: envelope, target: target)
        }

        guard let transport else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
        }
        return try await transport.call(envelope)
    }

    private func execute(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget
    ) async throws -> ResponseEnvelope {
        #if !hasFeature(Embedded)
        if let environment = registeredEnvironment(for: envelope.recipientID) {
            return try await EnvironmentValues.withValue(environment) {
                try await self.executeResolved(envelope: envelope, target: target)
            }
        }
        #endif
        return try await executeResolved(envelope: envelope, target: target)
    }

    private func registeredEnvironment(for id: ActorID) -> EnvironmentValues? {
        guard let separator = id.firstIndex(of: ":") else {
            return nil
        }
        return activators.withLock { $0[String(id[..<separator])] }?.environment
    }

    private func executeResolved(
        envelope: InvocationEnvelope,
        target: RemoteCallTarget
    ) async throws -> ResponseEnvelope {
        guard let actor = try registry.find(id: envelope.recipientID) ?? activatedActor(id: envelope.recipientID) else {
            throw RuntimeError.actorNotFound(envelope.recipientID)
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

        guard let response = await resultStore.response else {
            throw RuntimeError.executionFailed("No result captured", underlying: "Unknown")
        }
        return response
    }

    /// Activates the virtual actor an ID targets when an `ActorGroup` factory
    /// is registered for its contract. The lock makes activation per-ID
    /// single-flight: concurrent messages for the same ID get one instance.
    private func activatedActor(id: ActorID) throws -> (any DistributedActor)? {
        guard let separator = id.firstIndex(of: ":") else {
            return nil
        }
        let contract = String(id[..<separator])
        guard let activator = activators.withLock({ $0[contract] }) else {
            return nil
        }
        return try activationLock.withLock { _ in
            if let existing = registry.find(id: id) {
                return existing
            }
            WebActorActivationContext.withValue(WebActorPendingID(id)) {
                activator.activate()
            }
            guard let activated = registry.find(id: id) else {
                throw RuntimeError.executionFailed(
                    "ActorGroup factory did not create a \(contract) on this actor system for id '\(id)'",
                    underlying: "The factory must construct the actor with the app's actor system"
                )
            }
            return activated
        }
    }
}

private struct WebActorActivator: Sendable {
    let environment: EnvironmentValues
    let activate: @Sendable () -> Void
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
