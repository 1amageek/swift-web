import Vapor

public struct StrictTransportSecurityPolicy: Sendable {
    public var maxAge: Int
    public var includesSubdomains: Bool
    public var preload: Bool
    public var onlyWhenSecure: Bool

    public init(
        maxAge: Int = 31_536_000,
        includesSubdomains: Bool = true,
        preload: Bool = false,
        onlyWhenSecure: Bool = true
    ) {
        self.maxAge = maxAge
        self.includesSubdomains = includesSubdomains
        self.preload = preload
        self.onlyWhenSecure = onlyWhenSecure
    }

    public static let oneYear = StrictTransportSecurityPolicy()

    func headerValue() -> String {
        var parts = ["max-age=\(maxAge)"]
        if includesSubdomains {
            parts.append("includeSubDomains")
        }
        if preload {
            parts.append("preload")
        }
        return parts.joined(separator: "; ")
    }
}
