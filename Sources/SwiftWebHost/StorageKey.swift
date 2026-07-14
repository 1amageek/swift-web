/// A typed key into `ApplicationStorage`, replacing `Vapor.StorageKey`.
public protocol StorageKey {
    associatedtype Value: Sendable
}
