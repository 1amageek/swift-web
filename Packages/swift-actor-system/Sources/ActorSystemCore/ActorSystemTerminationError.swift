public enum ActorSystemTerminationError: Error, Sendable, Equatable {
    case reentrantWait
}
