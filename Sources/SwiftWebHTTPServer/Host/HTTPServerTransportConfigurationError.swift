import TLS

/// Configuration failures detected before SwiftWeb binds a secure listener.
public enum HTTPServerTransportConfigurationError: Error, Sendable, Equatable {
    case missingServerIdentity
    case unsupportedApplicationProtocol(String)
    case invalidTLSConfiguration(TLSError)
}
