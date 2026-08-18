import SwiftWebActors

public protocol App: SendableMetatype {
    associatedtype Body: Scene

    init()

    var clientRuntime: ClientRuntimeConfiguration { get }
    /// Defines the app-wide HTTP security policy.
    var security: SecurityConfiguration { get }

    /// The actor system hosting the app's distributed actors. `ActorGroup`
    /// factories construct their actors with it:
    ///
    ///     ActorGroup {
    ///         SupportAgent(actorSystem: actorSystem)
    ///     }
    ///
    /// Must return the same instance for the app's lifetime.
    var actorSystem: WebActorSystem { get }

    #if SWIFTWEB_LEGACY_ACTORS
    /// Compatibility system for applications still using `@Resolvable` and
    /// the legacy JSON actor endpoint.
    @available(*, deprecated, message: "Migrate actors to WebActorSystem")
    var legacyActorSystem: LegacyWebActorSystem { get }
    #endif

    @SceneBuilder
    var body: Body { get }
}

public extension App {
    var clientRuntime: ClientRuntimeConfiguration {
        .disabled
    }

    var security: SecurityConfiguration {
        .defaults
    }

    var actorSystem: WebActorSystem {
        .shared
    }

    #if SWIFTWEB_LEGACY_ACTORS
    var legacyActorSystem: LegacyWebActorSystem { .shared }
    #endif
}
