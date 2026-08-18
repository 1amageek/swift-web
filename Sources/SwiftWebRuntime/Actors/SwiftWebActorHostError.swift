import ActorSystemCore

public enum SwiftWebActorHostError: Error, Sendable, Equatable {
    case duplicateFactory(ActorTypeID)
    case factoryNotFound(ActorTypeID)
    case hostShuttingDown
    case authorizationConfigurationLocked
    case configurationLocked
    case duplicateActiveActor(ActorAddress)
    case actorIsBound(ActorAddress)
    case actorBusy(ActorAddress)
    case duplicatePersistentStorageKey(actorID: String)
    case actorNotRemindable(address: ActorAddress, name: String)
}
