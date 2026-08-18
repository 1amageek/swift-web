public struct ActorCompilerTargetKey: Hashable, Sendable {
    public let actorSymbol: String
    public let canonicalMethodSignature: String

    public init(actorSymbol: String, canonicalMethodSignature: String) {
        self.actorSymbol = actorSymbol
        self.canonicalMethodSignature = canonicalMethodSignature
    }
}

public struct ActorCompilerTargetMapping: Hashable, Sendable {
    public let key: ActorCompilerTargetKey
    public let targetIdentifier: String

    public init(key: ActorCompilerTargetKey, targetIdentifier: String) {
        self.key = key
        self.targetIdentifier = targetIdentifier
    }
}

public protocol ActorCompilerTargetMappingProvider: Sendable {
    func mappings(
        for actors: [ActorSourceModel]
    ) throws -> [ActorCompilerTargetMapping]
}
