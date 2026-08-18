import ActorSystemCore

public extension ActorTransportID {
    static let swiftWebHTTP = ActorTransportID("swiftweb.http")
    static let swiftWebWebSocket = ActorTransportID("swiftweb.websocket")
}

public extension ActorEndpoint {
    static let swiftWebHTTP = ActorEndpoint("/_swiftweb/actors/frame")
    static let swiftWebWebSocket = ActorEndpoint("/_swiftweb/actors/socket")
}
