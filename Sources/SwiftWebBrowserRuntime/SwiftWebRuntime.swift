import Vapor

package enum SwiftWebRuntime {
    package static var streamsResponses: Bool {
        Vapor.Environment.get("SWIFT_WEB_ENABLE_STREAMING_RESPONSES") == "1"
    }

    package static var vaporWebSockets: Bool {
        Vapor.Environment.get("SWIFT_WEB_ENABLE_VAPOR_WEBSOCKETS") == "1"
    }
}
