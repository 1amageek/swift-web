import SwiftWeb

public struct CounterApp: SwiftWeb.App {
    public init() {}

    public var security: SecurityConfiguration {
        var configuration = SecurityConfiguration.defaults
        configuration.actors = .allowAll
        return configuration
    }

    public var body: some Scene {
        Redirect("/", to: "/counter")

        ActorGroup(
            scope: .addressed(authorization: .allowAll)
        ) { actorSystem in
            CounterService(actorSystem: actorSystem)
        }

        CounterPage()
            .actor(
                CounterService.self,
                identity: CounterServiceIdentity.primary
            )
    }
}
