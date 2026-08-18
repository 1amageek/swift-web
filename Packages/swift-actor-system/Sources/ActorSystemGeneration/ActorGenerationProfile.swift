public enum ActorGenerationProfile: String, Codable, Hashable, Sendable {
    case nativeHost
    case standardClient
    case embeddedHost
    case embeddedClient
}

public struct GeneratedActorSource: Hashable, Sendable {
    public let relativePath: String
    public let contents: String

    public init(relativePath: String, contents: String) {
        self.relativePath = relativePath
        self.contents = contents
    }
}
