import Foundation

package enum SwiftWebRuntime {
    package static var streamsResponses: Bool {
        ProcessInfo.processInfo.environment["SWIFT_WEB_ENABLE_STREAMING_RESPONSES"] == "1"
    }

    package static var hostWebSockets: Bool {
        ProcessInfo.processInfo.environment["SWIFT_WEB_ENABLE_VAPOR_WEBSOCKETS"] == "1"
    }
}
