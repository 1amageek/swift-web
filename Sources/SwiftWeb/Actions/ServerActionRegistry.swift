import Distributed
import Foundation
import SwiftWebActors
import Synchronization
import Vapor

public final class ServerActionRegistry: Sendable {
    private struct State: Sendable {
        var actions: [ServerActionKey: RegisteredServerAction] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    public func register<Act>(
        actor: Act,
        descriptor: ServerActionDescriptor
    ) where Act: DistributedActor & Sendable, Act.ID == WebActorSystem.ActorID, Act.ActorSystem == WebActorSystem {
        let action = RegisteredServerAction(
            actorID: actor.id,
            actor: actor,
            actorName: descriptor.actorName,
            methodName: descriptor.methodName,
            targetIdentifier: descriptor.targetIdentifier,
            capabilityToken: descriptor.capabilityToken,
            descriptor: descriptor
        )
        state.withLock { state in
            state.actions[action.key] = action
        }
    }

    func action(
        actorName: String,
        methodName: String,
        metadata: ActionRequestMetadata
    ) throws -> RegisteredServerAction {
        guard let actorID = metadata.actorID else {
            throw Abort(.forbidden, reason: "Server action actor identity is missing")
        }
        guard metadata.actionName == nil || metadata.actionName == methodName else {
            throw Abort(.forbidden, reason: "Server action name mismatch")
        }

        let key = ServerActionKey(actorID: actorID, methodName: methodName)
        guard let action = state.withLock({ $0.actions[key] }) else {
            throw Abort(.notFound, reason: "Server action is not registered")
        }
        guard action.actorName == actorName else {
            throw Abort(.forbidden, reason: "Server action actor type mismatch")
        }
        guard metadata.targetIdentifier == nil || metadata.targetIdentifier == action.targetIdentifier else {
            throw Abort(.forbidden, reason: "Server action target mismatch")
        }
        if !action.capabilityToken.isEmpty {
            guard metadata.capabilityToken == action.capabilityToken else {
                throw Abort(.forbidden, reason: "Server action capability token mismatch")
            }
        }
        return action
    }
}

struct RegisteredServerAction: Sendable {
    let actorID: String
    let actor: any Sendable
    let actorName: String
    let methodName: String
    let targetIdentifier: String
    let capabilityToken: String
    let descriptor: ServerActionDescriptor

    var key: ServerActionKey {
        ServerActionKey(actorID: actorID, methodName: methodName)
    }
}

struct ServerActionKey: Hashable, Sendable {
    let actorID: String
    let methodName: String
}

private struct ServerActionRegistryStorageKey: StorageKey {
    typealias Value = ServerActionRegistry
}

public extension Application {
    var swiftWebServerActions: ServerActionRegistry {
        if let registry = storage[ServerActionRegistryStorageKey.self] {
            return registry
        }
        let registry = ServerActionRegistry()
        storage[ServerActionRegistryStorageKey.self] = registry
        return registry
    }
}
