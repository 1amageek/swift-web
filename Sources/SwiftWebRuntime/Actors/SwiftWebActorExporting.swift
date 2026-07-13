#if SWIFTWEB_ACTORS
@preconcurrency import Distributed

public protocol SwiftWebActorExporting: DistributedActor
where ID == WebActorSystem.ActorID, ActorSystem == WebActorSystem {
    associatedtype SwiftWebActorContract: DistributedActor
    where SwiftWebActorContract.ID == WebActorSystem.ActorID,
          SwiftWebActorContract.ActorSystem == WebActorSystem

    static var swiftWebActorContractKey: SwiftWebActorContractKey { get }
}
#endif
