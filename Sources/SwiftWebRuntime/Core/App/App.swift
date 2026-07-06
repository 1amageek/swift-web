import SwiftWebActors

public protocol App {
    associatedtype Body: Scene
    associatedtype Services: AppServices = EmptyAppServices

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

    @AppServiceBuilder
    var services: Services { get }

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
}

public extension App where Services == EmptyAppServices {
    var services: EmptyAppServices {
        EmptyAppServices()
    }
}
