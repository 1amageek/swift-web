import Synchronization

/// The virtual-actor ID a factory is being activated for. The first actor the
/// factory creates whose type matches the ID's contract prefix receives it;
/// any other actors the factory creates get regular generated IDs.
final class WebActorPendingID: Sendable {
    private let state: Mutex<String?>

    init(_ id: String) {
        self.state = Mutex(id)
    }

    func takeIfMatching(contract: String) -> String? {
        state.withLock { pending in
            guard let id = pending, id.hasPrefix("\(contract):") else {
                return nil
            }
            pending = nil
            return id
        }
    }
}

/// Carries the pending virtual-actor ID across the factory call during
/// activation, so `WebActorSystem.assignID` can bind the new instance to the
/// ID the incoming envelope targets.
enum WebActorActivationContext {
    #if hasFeature(Embedded)
    nonisolated(unsafe) static var current: WebActorPendingID?

    static func withValue<Result>(
        _ value: WebActorPendingID,
        operation: () throws -> Result
    ) rethrows -> Result {
        let previous = current
        current = value
        defer { current = previous }
        return try operation()
    }
    #else
    @TaskLocal static var current: WebActorPendingID?

    static func withValue<Result>(
        _ value: WebActorPendingID,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(value, operation: operation)
    }
    #endif
}
