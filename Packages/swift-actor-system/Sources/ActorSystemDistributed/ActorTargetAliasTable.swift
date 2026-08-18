import ActorSystemCore

public struct ActorTargetAliasTable: Sendable {
    public let toolchainFingerprint: String
    private let methodByCompilerTarget: [String: ActorMethodID]
    private let compilerTargetByMethod: [ActorMethodID: String]

    public init(
        toolchainFingerprint: String,
        aliases: [String: ActorMethodID]
    ) throws {
        guard !toolchainFingerprint.isEmpty else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor target alias toolchain fingerprint is empty")
            )
        }
        var reverse: [ActorMethodID: String] = [:]
        for (target, method) in aliases {
            guard !target.isEmpty, reverse[method] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("Actor target aliases are not one-to-one")
                )
            }
            reverse[method] = target
        }
        self.toolchainFingerprint = toolchainFingerprint
        self.methodByCompilerTarget = aliases
        self.compilerTargetByMethod = reverse
    }

    var methodIDs: Set<ActorMethodID> {
        Set(compilerTargetByMethod.keys)
    }

    public func methodID(forCompilerTarget target: String) -> ActorMethodID? {
        methodByCompilerTarget[target]
    }

    public func compilerTarget(for method: ActorMethodID) -> String? {
        compilerTargetByMethod[method]
    }

    func isEquivalent(to other: ActorTargetAliasTable) -> Bool {
        guard toolchainFingerprint == other.toolchainFingerprint,
              compilerTargetByMethod.count == other.compilerTargetByMethod.count
        else {
            return false
        }
        return compilerTargetByMethod.allSatisfy { method, target in
            other.compilerTargetByMethod[method] == target
        }
    }
}
