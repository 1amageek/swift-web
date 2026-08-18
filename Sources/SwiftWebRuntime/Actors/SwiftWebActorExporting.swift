#if SWIFTWEB_LEGACY_ACTORS
@preconcurrency import Distributed

@available(*, deprecated, message: "Concrete actors use ActorSystemReference metadata")
public protocol LegacySwiftWebActorExporting: DistributedActor
where ID == LegacyWebActorSystem.ActorID, ActorSystem == LegacyWebActorSystem {
    associatedtype SwiftWebActorContract: DistributedActor
    where SwiftWebActorContract.ID == LegacyWebActorSystem.ActorID,
          SwiftWebActorContract.ActorSystem == LegacyWebActorSystem

    static var swiftWebActorContractKey: SwiftWebActorContractKey { get }
}
#endif
