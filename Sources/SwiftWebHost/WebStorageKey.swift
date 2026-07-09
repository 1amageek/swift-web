/// A typed key into `WebApplicationStorage`, replacing `Vapor.StorageKey`.
public protocol WebStorageKey {
    associatedtype Value: Sendable
}
