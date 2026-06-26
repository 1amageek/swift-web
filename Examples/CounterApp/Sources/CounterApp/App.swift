import SwiftWeb

public struct CounterApp: SwiftWeb.App {
    public init() {}

    public var body: some Scene {
        Redirect("/", to: "/counter")
        CounterPage()
    }
}
