import Foundation

public struct SwiftWebDevRuntimeConfiguration: Sendable {
    public var packageDirectory: URL
    public var scratchDirectory: URL?
    public var product: String
    public var host: String
    public var port: Int
    public var readinessTimeout: TimeInterval

    public init(
        packageDirectory: URL,
        scratchDirectory: URL? = nil,
        product: String = "app-server",
        host: String = "127.0.0.1",
        port: Int = 3000,
        readinessTimeout: TimeInterval = 30
    ) {
        self.packageDirectory = packageDirectory.standardizedFileURL
        self.scratchDirectory = scratchDirectory?.standardizedFileURL
        self.product = product
        self.host = host
        self.port = port
        self.readinessTimeout = readinessTimeout
    }
}
