import ActorSystemCore
import Distributed
import Synchronization

final class ActorDistributedTypeRegistry: Sendable {
    fileprivate struct State: Sendable {
        var registrationsBySwiftType: [ObjectIdentifier: AnyDistributedActorTypeRegistration] = [:]
        var swiftTypeByActorTypeID: [ActorTypeID: ObjectIdentifier] = [:]
        // This is an intra-registry consistency value, not an assertion about
        // the compiler executing this runtime. The build/materialization layer
        // remains authoritative for matching generated aliases to the selected
        // compiler fingerprint.
        var toolchainFingerprint: String?
    }

    private let state = Mutex(State())

    struct Checkpoint: Sendable {
        fileprivate let state: State
    }

    func checkpoint() -> Checkpoint {
        state.withLock { Checkpoint(state: $0) }
    }

    func restore(_ checkpoint: Checkpoint) {
        state.withLock { $0 = checkpoint.state }
    }

    func register(_ registration: AnyDistributedActorTypeRegistration) throws {
        try registration.descriptor.validate()
        let descriptorMethodIDs = Set(
            registration.descriptor.methods.map(\.id)
        )
        guard registration.aliases.methodIDs == descriptorMethodIDs else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation(
                    "Distributed actor target aliases do not match the descriptor methods"
                )
            )
        }
        try state.withLock { state in
            if let expected = state.toolchainFingerprint {
                guard expected == registration.aliases.toolchainFingerprint else {
                    throw ActorSystemError.invalidFrame(
                        ActorProtocolViolation(
                            "Distributed actor registrations use different toolchain fingerprints"
                        )
                    )
                }
            }
            if let existing = state.registrationsBySwiftType[registration.swiftTypeID] {
                guard existing.descriptor == registration.descriptor,
                      existing.aliases.isEquivalent(to: registration.aliases),
                      state.swiftTypeByActorTypeID[registration.descriptor.id]
                        == registration.swiftTypeID
                else {
                    throw ActorSystemError.invalidFrame(
                        ActorProtocolViolation(
                            "A distributed actor type has conflicting registrations"
                        )
                    )
                }
                if state.toolchainFingerprint == nil {
                    state.toolchainFingerprint = registration.aliases.toolchainFingerprint
                }
                return
            }
            if state.swiftTypeByActorTypeID[registration.descriptor.id] != nil {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("An actor type ID is registered more than once")
                )
            }
            if state.toolchainFingerprint == nil {
                state.toolchainFingerprint = registration.aliases.toolchainFingerprint
            }
            state.registrationsBySwiftType[registration.swiftTypeID] = registration
            state.swiftTypeByActorTypeID[registration.descriptor.id] = registration.swiftTypeID
        }
    }

    func registration<Act>(for actorType: Act.Type) -> AnyDistributedActorTypeRegistration?
    where Act: DistributedActor {
        state.withLock { state in
            state.registrationsBySwiftType[ObjectIdentifier(actorType)]
        }
    }

    func validateBootstrapDeclaration(
        _ descriptors: [ActorTypeDescriptor],
        bootstrapIdentifier: String
    ) throws {
        _ = try descriptorMap(
            descriptors,
            bootstrapIdentifier: bootstrapIdentifier
        )
    }

    func validateBootstrapRegistrations(
        _ registrations: [AnyDistributedActorTypeRegistration],
        declaredDescriptors: [ActorTypeDescriptor],
        bootstrapIdentifier: String
    ) throws {
        let declared = try descriptorMap(
            declaredDescriptors,
            bootstrapIdentifier: bootstrapIdentifier
        )
        var actual: [ActorTypeID: AnyDistributedActorTypeRegistration] = [:]
        for registration in registrations {
            guard actual.updateValue(registration, forKey: registration.descriptor.id) == nil else {
                throw bootstrapViolation(
                    bootstrapIdentifier,
                    "registers the same actor type ID more than once"
                )
            }
        }

        guard Set(actual.keys) == Set(declared.keys) else {
            throw bootstrapViolation(
                bootstrapIdentifier,
                "declared actor descriptors do not match its actor registrations"
            )
        }
        for (typeID, descriptor) in declared {
            guard actual[typeID]?.descriptor == descriptor else {
                throw bootstrapViolation(
                    bootstrapIdentifier,
                    "registered actor descriptor does not match its declaration for type ID \(typeID.high):\(typeID.low)"
                )
            }
        }

        try state.withLock { state in
            for registration in registrations {
                guard let stored = state.registrationsBySwiftType[registration.swiftTypeID],
                      stored.descriptor == registration.descriptor,
                      stored.aliases.isEquivalent(to: registration.aliases),
                      state.swiftTypeByActorTypeID[registration.descriptor.id]
                        == registration.swiftTypeID
                else {
                    throw bootstrapViolation(
                        bootstrapIdentifier,
                        "actor registration is not present in the transaction registry state"
                    )
                }
            }
        }
    }

    private func descriptorMap(
        _ descriptors: [ActorTypeDescriptor],
        bootstrapIdentifier: String
    ) throws -> [ActorTypeID: ActorTypeDescriptor] {
        var result: [ActorTypeID: ActorTypeDescriptor] = [:]
        for descriptor in descriptors {
            try descriptor.validate()
            guard result.updateValue(descriptor, forKey: descriptor.id) == nil else {
                throw bootstrapViolation(
                    bootstrapIdentifier,
                    "declares the same actor type ID more than once"
                )
            }
        }
        return result
    }

    private func bootstrapViolation(
        _ bootstrapIdentifier: String,
        _ reason: String
    ) -> ActorSystemError {
        ActorSystemError.invalidFrame(
            ActorProtocolViolation(
                "Actor bootstrap \(bootstrapIdentifier) \(reason)"
            )
        )
    }
}

final class LocalDistributedActorStore: Sendable {
    private let actors = Mutex<[ActorAddress: any DistributedActor]>([:])

    func register(_ actor: any DistributedActor, address: ActorAddress) throws {
        try actors.withLock { actors in
            guard actors[address] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("A distributed actor address is registered more than once")
                )
            }
            actors[address] = actor
        }
    }

    func actor<Act>(at address: ActorAddress, as type: Act.Type) -> Act?
    where Act: DistributedActor {
        actors.withLock { actors in
            actors[address] as? Act
        }
    }

    @discardableResult
    func unregister(address: ActorAddress) -> (any DistributedActor)? {
        actors.withLock { actors in
            actors.removeValue(forKey: address)
        }
    }

    func removeAll() -> [any DistributedActor] {
        actors.withLock { actors in
            let removed = Array(actors.values)
            actors.removeAll(keepingCapacity: false)
            return removed
        }
    }
}
