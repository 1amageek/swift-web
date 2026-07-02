public protocol App {
    associatedtype Body: Scene
    associatedtype Services: AppServices = EmptyAppServices

    init()

    var clientRuntime: ClientRuntimeConfiguration { get }
    /// Defines the app-wide HTTP security policy.
    var security: SecurityConfiguration { get }

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
}

public extension App where Services == EmptyAppServices {
    var services: EmptyAppServices {
        EmptyAppServices()
    }
}
