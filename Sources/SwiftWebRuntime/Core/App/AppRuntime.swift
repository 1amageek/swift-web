@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
import ActorSystemEmbedded
import SwiftWebActors
@_spi(Hosting) import SwiftWebHost
import Synchronization

/// Framework-owned state shared while an app is rendered and while its
/// registered handlers serve requests.
package final class AppRuntime: Sendable {
    package let routes: Routes
    package let requestContext: RequestRuntimeContext
    package let actorSystem: WebActorSystem
    #if SWIFTWEB_LEGACY_ACTORS
    package let legacyActorSystem: LegacyWebActorSystem
    #endif
    private let actorSystemRequired = Mutex(false)
    private let lifecycle: ActorSystemLifecycleCoordinator

    #if SWIFTWEB_LEGACY_ACTORS
    package init(
        serverConfiguration: ServerConfiguration,
        actorSystem: WebActorSystem,
        legacyActorSystem: LegacyWebActorSystem
    ) {
        self.routes = Routes()
        self.requestContext = RequestRuntimeContext(
            serverConfiguration: serverConfiguration
        )
        self.actorSystem = actorSystem
        self.legacyActorSystem = legacyActorSystem
        self.lifecycle = Self.makeLifecycle(
            actorSystem: actorSystem,
            additionalTerminations: {
                [legacyActorSystem.requestShutdown()]
            }
        )
    }
    #else
    package init(
        serverConfiguration: ServerConfiguration,
        actorSystem: WebActorSystem
    ) {
        self.routes = Routes()
        self.requestContext = RequestRuntimeContext(
            serverConfiguration: serverConfiguration
        )
        self.actorSystem = actorSystem
        self.lifecycle = Self.makeLifecycle(actorSystem: actorSystem)
    }
    #endif

    private static func makeLifecycle(
        actorSystem: WebActorSystem,
        additionalTerminations: @escaping @Sendable () -> [ActorSystemTermination] = { [] }
    ) -> ActorSystemLifecycleCoordinator {
        #if SWIFTWEB_ACTORS || hasFeature(Embedded)
        return ActorSystemLifecycleCoordinator(
            start: {
                try await actorSystem.start()
            },
            requestShutdown: {
                let actorSystemTermination = await actorSystem.requestShutdown()
                let terminations = [actorSystemTermination] + additionalTerminations()
                return ActorSystemTermination(
                    dependencies: { terminations }
                )
            }
        )
        #else
        return ActorSystemLifecycleCoordinator(
            start: {},
            requestShutdown: {
                let terminations = additionalTerminations()
                guard !terminations.isEmpty else {
                    return .alreadyTerminated()
                }
                return ActorSystemTermination(
                    dependencies: { terminations }
                )
            }
        )
        #endif
    }

    package convenience init(serverConfiguration: ServerConfiguration) {
        #if SWIFTWEB_LEGACY_ACTORS
        self.init(
            serverConfiguration: serverConfiguration,
            actorSystem: .shared,
            legacyActorSystem: .shared
        )
        #else
        self.init(
            serverConfiguration: serverConfiguration,
            actorSystem: .shared
        )
        #endif
    }

    package func requireActorSystem() {
        actorSystemRequired.withLock { $0 = true }
    }

    package var requiresActorSystem: Bool {
        actorSystemRequired.withLock { $0 }
    }

    package func start() async throws {
        guard requiresActorSystem else {
            return
        }
        try await lifecycle.start()
    }

    package func requestShutdown() async -> ActorSystemTermination {
        guard requiresActorSystem else {
            return .alreadyTerminated()
        }
        return await lifecycle.requestShutdown()
    }

    package func shutdown() async throws {
        try await requestShutdown().wait()
    }
}
