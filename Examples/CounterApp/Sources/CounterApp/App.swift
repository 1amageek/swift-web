import SwiftWeb

public struct CounterApp: SwiftWeb.App {
    public init() {}

    public var body: some AppContent {
        Redirect("/", to: "/counter")
        CounterPage()
    }
}
