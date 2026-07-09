import Logging

/// The host-neutral application the SwiftWeb core registers routes and
/// services on, replacing `Vapor.Application`. Host adapters provide the
/// conformance and lower the collected routes onto their native server.
public protocol WebApplicationProtocol: AnyObject, Sendable {
    var logger: Logger { get }
    var routes: any WebRoutesBuilder { get }
    var storage: WebApplicationStorage { get }
    var serverConfiguration: WebServerConfiguration { get }
}
