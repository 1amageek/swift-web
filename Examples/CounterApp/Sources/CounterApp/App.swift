import SwiftWeb

public struct CounterApp: SwiftWeb.App {
    private let counterService: CounterService

    public init() {
        self.counterService = CounterService(actorSystem: .shared)
    }

    public var body: some Scene {
        Redirect("/", to: "/counter")
        ActorScene(counterService) {
            CounterPage(counterService: counterService)
        }
    }
}
