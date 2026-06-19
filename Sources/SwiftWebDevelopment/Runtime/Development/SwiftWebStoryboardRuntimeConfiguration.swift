import Foundation

public struct SwiftWebStoryboardRuntimeConfiguration: Sendable {
    public let packageDirectory: URL
    public let storyboardDirectory: URL?
    public let scratchDirectory: URL?
    public let host: String
    public let port: Int
    public let runsServer: Bool
    public let force: Bool

    public init(
        packageDirectory: URL,
        storyboardDirectory: URL? = nil,
        scratchDirectory: URL? = nil,
        host: String,
        port: Int,
        runsServer: Bool,
        force: Bool
    ) {
        self.packageDirectory = packageDirectory.standardizedFileURL
        self.storyboardDirectory = storyboardDirectory?.standardizedFileURL
        self.scratchDirectory = scratchDirectory?.standardizedFileURL
        self.host = host
        self.port = port
        self.runsServer = runsServer
        self.force = force
    }
}
