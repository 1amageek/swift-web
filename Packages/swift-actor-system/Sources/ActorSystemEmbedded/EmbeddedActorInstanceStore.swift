import ActorSystemCore
import Synchronization

final class EmbeddedActorInstanceStore: Sendable {
    private struct Entry: Sendable {
        let instance: any EmbeddedActorInstance
        let typeIdentity: ObjectIdentifier
        private let opaquePointer: @Sendable () -> UnsafeRawPointer

        init<Instance: EmbeddedActorInstance>(_ instance: Instance) {
            self.instance = instance
            self.typeIdentity = ObjectIdentifier(Instance.self)
            self.opaquePointer = {
                UnsafeRawPointer(Unmanaged.passUnretained(instance).toOpaque())
            }
        }

        func instance<Instance: EmbeddedActorInstance>(as type: Instance.Type) -> Instance? {
            guard typeIdentity == ObjectIdentifier(Instance.self) else {
                return nil
            }
            // `instance` owns the object for this entire borrow. The closure
            // exposes its concrete pointer only for this immediate, checked
            // reconstruction; the pointer is neither stored nor sent across
            // an isolation boundary.
            return Unmanaged<Instance>
                .fromOpaque(opaquePointer())
                .takeUnretainedValue()
        }
    }

    private let instances = Mutex<[ActorAddress: Entry]>([:])

    func register<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        at address: ActorAddress
    ) throws {
        try instances.withLock { instances in
            guard instances[address] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("An Embedded actor address is registered more than once")
                )
            }
            instances[address] = Entry(instance)
        }
    }

    func instance<Instance: EmbeddedActorInstance>(
        at address: ActorAddress,
        as type: Instance.Type
    ) -> Instance? {
        instances.withLock { instances in
            instances[address]?.instance(as: type)
        }
    }

    @discardableResult
    func unregister(address: ActorAddress) -> (any EmbeddedActorInstance)? {
        instances.withLock { instances in
            instances.removeValue(forKey: address)?.instance
        }
    }

    func removeAll() -> [any EmbeddedActorInstance] {
        instances.withLock { instances in
            let removed = instances.values.map { entry in entry.instance }
            instances.removeAll(keepingCapacity: false)
            return removed
        }
    }
}
