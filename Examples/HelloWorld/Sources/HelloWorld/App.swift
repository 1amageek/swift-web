import SwiftWeb

public struct HelloWorld: SwiftWeb.App {
    public init() {}

    public var body: some AppContent {
        HelloPage()
    }
}
