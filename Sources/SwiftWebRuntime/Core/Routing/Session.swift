@propertyWrapper
public struct Session: Sendable {
    public init() {}

    public var wrappedValue: RequestSession {
        ServerCapabilityReadContext.record("@Session", valueType: RequestSession.self)
        guard let context = RequestContext.current else {
            preconditionFailure("@Session was accessed outside a SwiftWeb page request")
        }
        return context.request.session
    }
}
