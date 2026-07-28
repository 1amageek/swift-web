import Synchronization

public enum ClientRuntimeAccessError: Error, Sendable, CustomStringConvertible {
    case concurrentOperation

    public var description: String {
        switch self {
        case .concurrentOperation:
            "SwiftHTML browser runtime rejected a concurrent or re-entrant operation"
        }
    }
}

final class ClientRuntimeAccessGate: Sendable {
    private let isExecuting = Mutex(false)

    func withExclusiveAccess<Result>(
        _ operation: () throws -> Result
    ) throws -> Result {
        let acquired = isExecuting.withLock { isExecuting in
            guard !isExecuting else {
                return false
            }
            isExecuting = true
            return true
        }
        guard acquired else {
            throw ClientRuntimeAccessError.concurrentOperation
        }
        defer {
            isExecuting.withLock { isExecuting in
                isExecuting = false
            }
        }
        return try operation()
    }
}
