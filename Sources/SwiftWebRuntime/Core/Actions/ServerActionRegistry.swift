#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class ServerActionRegistry: Sendable {
    private struct State: Sendable {
        var actions: [ServerActionKey: RegisteredServerAction] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    public func register<Handler>(
        handler: Handler,
        descriptor: ServerActionDescriptor,
        path: String? = nil
    ) throws where Handler: Sendable {
        let action = RegisteredServerAction(
            path: path ?? descriptor.path,
            method: descriptor.method,
            handler: handler,
            descriptor: descriptor
        )
        try state.withLock { state in
            if state.actions[action.key] != nil {
                throw Abort(.conflict, reason: "Server action route is already registered")
            }
            state.actions[action.key] = action
        }
    }

    func action(
        method: ServerActionMethod,
        path: String
    ) throws -> RegisteredServerAction {
        let key = ServerActionKey(method: method, path: path)
        guard let action = state.withLock({ $0.actions[key] }) else {
            throw Abort(.notFound, reason: "Server action route is not registered")
        }
        return action
    }
}

struct RegisteredServerAction: Sendable {
    let path: String
    let method: ServerActionMethod
    let handler: any Sendable
    let descriptor: ServerActionDescriptor

    var key: ServerActionKey {
        ServerActionKey(method: method, path: path)
    }
}

struct ServerActionKey: Hashable, Sendable {
    let method: ServerActionMethod
    let path: String
}

private struct ServerActionRegistryStorageKey: StorageKey {
    typealias Value = ServerActionRegistry
}

public extension WebApplicationProtocol {
    var swiftWebServerActions: ServerActionRegistry {
        if let registry = storage[ServerActionRegistryStorageKey.self] {
            return registry
        }
        let registry = ServerActionRegistry()
        storage[ServerActionRegistryStorageKey.self] = registry
        return registry
    }
}
