import Vapor

enum SwiftWebRuntime {
    static var streamsResponses: Bool {
        Vapor.Environment.get("SWIFT_WEB_ENABLE_STREAMING_RESPONSES") == "1"
    }

    static var vaporWebSockets: Bool {
        Vapor.Environment.get("SWIFT_WEB_ENABLE_VAPOR_WEBSOCKETS") == "1"
    }
}
