#if canImport(Logging)
import Logging
#endif

/// The host-neutral application the SwiftWeb core registers routes and
/// services on, replacing `Vapor.Application`. Host adapters provide the
/// conformance and lower the collected routes onto their native server.
public protocol ApplicationProtocol: AnyObject, Sendable {
    var logger: Logger { get }
    var routes: any RoutesBuilder { get }
    var storage: ApplicationStorage { get }
    var serverConfiguration: ServerConfiguration { get }
}
