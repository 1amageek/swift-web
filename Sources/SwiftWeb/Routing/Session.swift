@propertyWrapper
public struct Session: Sendable {
    public init() {}

    public var wrappedValue: WebSession {
        ServerCapabilityReadContext.record("@Session", valueType: WebSession.self)
        guard let context = RequestContext.current else {
            preconditionFailure("@Session was accessed outside a SwiftWeb page request")
        }
        return WebSession.vapor(context.request)
    }
}
