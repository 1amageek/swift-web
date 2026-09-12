import SwiftWeb

public struct StoryboardApp: SwiftWeb.App {
    public init() {}

    public var body: some Scene {
        Redirect("/", to: "/storyboard")
        StoryboardPage()
        StoryboardSelectionPage()
    }
}
