import ActorSystemCore

enum JavaScriptKitActorRequestErrorNormalizer {
    static func normalize(
        _ error: any Error,
        isCancelled: Bool,
        isAccepting: Bool
    ) -> ActorSystemError {
        if isCancelled {
            return .cancelled
        }
        if !isAccepting {
            return .transportClosed
        }
        if let actorSystemError = error as? ActorSystemError {
            return actorSystemError
        }
        return .transportClosed
    }
}
